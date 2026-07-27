import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/home_widgets.dart';
import '../../services/home_widget_service.dart';
import '../../utils/say.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';

/// The row actions both lists offer.
enum _RowAction { edit, delete }

/// Sticky notes and quick links — the two things on Plane's workspace home
/// that belong to the person looking at it.
///
/// Both are per-user on the server: the views filter on the caller and set the
/// owner themselves, so there is no request shape that reaches anyone else's.
/// That is why they live on one screen rather than under project settings.
class HomeWidgetsScreen extends StatefulWidget {
  final String workspaceSlug;

  const HomeWidgetsScreen({super.key, required this.workspaceSlug});

  @override
  State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> {
  List<Sticky> _stickies = [];
  List<QuickLink> _links = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        HomeWidgetService.getStickies(widget.workspaceSlug),
        HomeWidgetService.getQuickLinks(widget.workspaceSlug),
      ]);
      if (!mounted) return;
      setState(() {
        _stickies = results[0] as List<Sticky>;
        _links = results[1] as List<QuickLink>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server';
      });
    }
  }

  // --- Stickies ------------------------------------------------------------

  Future<void> _editSticky([Sticky? existing]) async {
    final result = await _promptTwoFields(
      title: existing == null ? 'New note' : 'Edit note',
      firstLabel: 'Title',
      secondLabel: 'Note',
      firstInitial: existing?.name ?? '',
      secondInitial: _plainText(existing?.descriptionHtml ?? ''),
      secondLines: 6,
      confirmLabel: existing == null ? 'Add' : 'Save',
    );
    if (result == null) return;

    // A note with neither a title nor a body is a row that says nothing. The
    // server would accept it — `name` is not required — so the guard is here.
    if (result.first.isEmpty && result.second.isEmpty) return;

    try {
      if (existing == null) {
        await HomeWidgetService.createSticky(
          widget.workspaceSlug,
          name: result.first.isEmpty ? null : result.first,
          descriptionHtml: _html(result.second),
        );
      } else {
        await HomeWidgetService.updateSticky(
          widget.workspaceSlug,
          existing.id,
          {
            'name': result.first,
            'description_html': _html(result.second),
          },
        );
      }
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not save the note');
    }
  }

  Future<void> _deleteSticky(Sticky sticky) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete note?',
      message: 'This removes "${sticky.displayName}". There is no undo.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await HomeWidgetService.deleteSticky(widget.workspaceSlug, sticky.id);
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not delete the note');
    }
  }

  // --- Quick links ---------------------------------------------------------

  Future<void> _editLink([QuickLink? existing]) async {
    final result = await _promptTwoFields(
      title: existing == null ? 'New link' : 'Edit link',
      firstLabel: 'Title',
      secondLabel: 'URL',
      firstInitial: existing?.title ?? '',
      secondInitial: existing?.url ?? '',
      confirmLabel: existing == null ? 'Add' : 'Save',
    );
    if (result == null) return;
    if (result.second.isEmpty) {
      if (mounted) say(context, 'A link needs a URL');
      return;
    }

    // Plane stores the URL as text and does not normalise it, so a bare
    // "plane.so" would be saved and then fail to open.
    final url = result.second.contains('://')
        ? result.second
        : 'https://${result.second}';

    try {
      if (existing == null) {
        await HomeWidgetService.createQuickLink(
          widget.workspaceSlug,
          url: url,
          title: result.first.isEmpty ? null : result.first,
        );
      } else {
        await HomeWidgetService.updateQuickLink(
          widget.workspaceSlug,
          existing.id,
          {'url': url, 'title': result.first},
        );
      }
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not save the link');
    }
  }

  Future<void> _deleteLink(QuickLink link) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete link?',
      message: 'This removes "${link.displayTitle}".',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await HomeWidgetService.deleteQuickLink(widget.workspaceSlug, link.id);
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not delete the link');
    }
  }

  Future<void> _openLink(QuickLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) say(context, 'Could not open that link');
    }
  }

  // --- Shared --------------------------------------------------------------

  Future<_RowAction?> _rowMenu(String title) =>
      BottomSheetPicker.show<_RowAction>(
        context: context,
        title: title,
        items: const [
          BottomSheetPickerItem(
            value: _RowAction.edit,
            label: 'Edit',
            icon: Icons.edit_outlined,
          ),
          BottomSheetPickerItem(
            value: _RowAction.delete,
            label: 'Delete',
            icon: Icons.delete_outline,
            destructive: true,
          ),
        ],
      );

  /// A two-field dialog, because both editors are exactly that and a second
  /// hand-rolled one would be a second answer to a settled question.
  Future<({String first, String second})?> _promptTwoFields({
    required String title,
    required String firstLabel,
    required String secondLabel,
    required String firstInitial,
    required String secondInitial,
    required String confirmLabel,
    int secondLines = 1,
  }) async {
    final first = TextEditingController(text: firstInitial);
    final second = TextEditingController(text: secondInitial);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3ETextField(
                  label: firstLabel, controller: first, autofocus: true),
              const SizedBox(height: 12),
              M3ETextField(
                label: secondLabel,
                controller: second,
                maxLines: secondLines,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    final result = saved == true
        ? (first: first.text.trim(), second: second.text.trim())
        : null;
    first.dispose();
    second.dispose();
    return result;
  }

  static String _html(String text) =>
      text.isEmpty ? '<p></p>' : '<p>${text.replaceAll('\n', '<br>')}</p>';

  /// The inverse, well enough for an editor that only ever writes paragraphs.
  static String _plainText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Notes & links',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a note or a link',
            onPressed: _loading ? null : _showAddMenu,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ScrollableCenter(
                  child: ErrorStateWidget(message: _error, onRetry: _load),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _stickies.isEmpty && _links.isEmpty
                      ? const ScrollableEmptyState(
                          message: 'Nothing pinned yet',
                          icon: Icons.push_pin_outlined,
                          subtitle:
                              'Notes and links here are yours alone — nobody '
                              'else in the workspace can see them.',
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 32),
                          children: [
                            if (_stickies.isNotEmpty) ...[
                              const SectionHeader(label: 'Notes'),
                              for (final s in _stickies) _stickyRow(s),
                            ],
                            if (_links.isNotEmpty) ...[
                              const SectionHeader(label: 'Quick links'),
                              for (final l in _links) _linkRow(l),
                            ],
                          ],
                        ),
                ),
    );
  }

  Future<void> _showAddMenu() async {
    final picked = await BottomSheetPicker.show<String>(
      context: context,
      title: 'Add',
      items: const [
        BottomSheetPickerItem(
          value: 'note',
          label: 'Note',
          subtitle: 'A sticky on your workspace home',
          icon: Icons.sticky_note_2_outlined,
        ),
        BottomSheetPickerItem(
          value: 'link',
          label: 'Quick link',
          subtitle: 'A bookmark, yours alone',
          icon: Icons.link,
        ),
      ],
    );
    if (picked == 'note') await _editSticky();
    if (picked == 'link') await _editLink();
  }

  Widget _stickyRow(Sticky sticky) {
    final body = _plainText(sticky.descriptionHtml);
    return PlaneRow(
      icon: Icons.sticky_note_2_outlined,
      title: sticky.displayName,
      subtitle: body.isEmpty ? null : body,
      semanticLabel: 'Note: ${sticky.displayName}',
      onTap: () => _editSticky(sticky),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz),
        tooltip: 'Actions for ${sticky.displayName}',
        onPressed: () async {
          switch (await _rowMenu(sticky.displayName)) {
            case _RowAction.edit:
              await _editSticky(sticky);
            case _RowAction.delete:
              await _deleteSticky(sticky);
            case null:
              break;
          }
        },
      ),
    );
  }

  Widget _linkRow(QuickLink link) {
    return PlaneRow(
      icon: Icons.link,
      title: link.displayTitle,
      subtitle: link.url,
      semanticLabel: 'Link: ${link.displayTitle}',
      onTap: () => _openLink(link),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz),
        tooltip: 'Actions for ${link.displayTitle}',
        onPressed: () async {
          switch (await _rowMenu(link.displayTitle)) {
            case _RowAction.edit:
              await _editLink(link);
            case _RowAction.delete:
              await _deleteLink(link);
            case null:
              break;
          }
        },
      ),
    );
  }
}
