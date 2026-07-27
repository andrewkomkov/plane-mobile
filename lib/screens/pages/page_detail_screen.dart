import 'package:flutter/material.dart';
import '../../utils/api_error.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../utils/say.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/page_service.dart';
import '../../models/page.dart';
import '../../utils/html_to_markdown.dart';
import '../../utils/markdown_to_html.dart';
import '../../widgets/loading_state.dart';

class PageDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String pageId;
  final String pageName;

  const PageDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.pageId,
    required this.pageName,
  });

  @override
  ConsumerState<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends ConsumerState<PageDetailScreen> {
  PlanePage? _page;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await PageService.getPage(
          widget.workspaceSlug, widget.projectId, widget.pageId);
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPage() async {
    if (_page == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          pageId: widget.pageId,
          initialName: _page!.name,
          initialHtml: _page!.descriptionHtml ?? '',
        ),
      ),
    );
    if (result == true) _load();
  }

  String get _pageLabel {
    final name = _page?.name ?? widget.pageName;
    return name.isEmpty ? 'Untitled' : name;
  }

  Future<void> _archivePage() async {
    if (_page == null) return;
    // Reversible from the Archived list, so not the error role.
    final ok = await confirmAction(
      context,
      title: 'Archive page',
      message: 'Move "$_pageLabel" out of the project pages? Any page '
          'nested under it is archived too. It can be restored from the '
          'Archived list.',
      confirmLabel: 'Archive',
    );
    if (!ok) return;
    try {
      await PageService.archivePage(
          widget.workspaceSlug, widget.projectId, widget.pageId);
      // The list screen invalidates its page cache on every return from here,
      // so popping is what moves the row into the archive.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to archive'));
      }
    }
  }

  Future<void> _unarchivePage() async {
    if (_page == null) return;
    try {
      await PageService.unarchivePage(
          widget.workspaceSlug, widget.projectId, widget.pageId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to restore'));
      }
    }
  }

  /// Only reachable on an archived page.
  ///
  /// `PageViewSet.destroy` answers 400 "The page should be archived before
  /// deleting" for a live one, so the button used to sit on every page and
  /// fail on all of them. Archiving is the first half of the flow; this is the
  /// second, and the wording says so.
  Future<void> _deletePage() async {
    if (_page == null) return;
    // This one was the audit's example of the worst case: an irreversible
    // delete whose button was painted exactly like Cancel.
    final ok = await confirmDestructive(
      context,
      title: 'Delete page',
      message: 'Delete "$_pageLabel" permanently? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await PageService.deletePage(
          widget.workspaceSlug, widget.projectId, widget.pageId);
      // The list screen invalidates its page cache on every return from here,
      // so popping is all that is needed to make the row disappear.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, 'Error: $e');
      }
    }
  }

  /// Archive, restore and delete, in one surface.
  ///
  /// Delete is only offered once the page is archived, because that is the
  /// only state Plane will delete from — and it is shown disabled rather than
  /// hidden on a live page, so the two-step flow is visible before it is
  /// needed. Archive stays available on a locked page: the lock is Plane's
  /// guard against concurrent edits to the body and the server enforces it on
  /// PATCH only, while archiving is gated by ownership or project admin.
  Future<void> _showMoreMenu() async {
    final archived = _page?.archivedAt != null;
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: _pageLabel,
      items: [
        if (archived)
          const BottomSheetPickerItem(
            value: 'restore',
            label: 'Restore page',
            icon: Icons.unarchive_outlined,
          )
        else
          const BottomSheetPickerItem(
            value: 'archive',
            label: 'Archive page',
            icon: Icons.inventory_2_outlined,
          ),
        BottomSheetPickerItem(
          value: 'delete',
          label: 'Delete page',
          icon: Icons.delete_outline,
          destructive: true,
          enabled: archived,
          subtitle: archived ? null : 'Archive the page first',
        ),
      ],
    );
    switch (chosen) {
      case 'restore':
        await _unarchivePage();
      case 'archive':
        await _archivePage();
      case 'delete':
        await _deletePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archived = _page?.archivedAt != null;
    return Scaffold(
      appBar: M3EAppBar(
        title: _page?.name ?? widget.pageName,
        actions: [
          // Edit stays on the bar: it is the primary thing a reader does to a
          // page, and the cycle and module screens keep their primary action
          // out of the menu for the same reason.
          //
          // `pages/{id}/` PATCH would in fact accept an edit to an archived
          // page — only the binary-description endpoint refuses one — but an
          // archive a user can still type into is not an archive. Restore
          // first is the one path offered.
          if (_page != null && !_page!.isLocked && !archived)
            M3EAppBarAction(
                icon: Icons.edit,
                tooltip: 'Edit page',
                emphasized: true,
                onPressed: _editPage),
          // Everything else behind one `more_horiz`, which is the shape the
          // cycle and module detail screens use for the same three actions.
          // Three separate icons here made one screen out of three.
          if (_page != null)
            M3EAppBarAction(
              icon: Icons.more_horiz,
              tooltip: 'Page actions',
              onPressed: _showMoreMenu,
            ),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _page?.descriptionHtml != null && _page!.descriptionHtml!.isNotEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownBody(
                    data: htmlToMarkdown(_page!.descriptionHtml!),
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyLarge,
                      h1: theme.textTheme.headlineSmall,
                      h2: theme.textTheme.titleLarge,
                      h3: theme.textTheme.titleMedium,
                      code: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.08),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(M3EShape.large),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      // Not chrome, so not on the 0.8 hairline rule: this is
                      // the quote's typographic accent and has to read as one.
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(
                                color: theme.colorScheme.primary, width: 3)),
                      ),
                      blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                      listBullet: theme.textTheme.bodyLarge,
                    ),
                    selectable: true,
                  ),
                )
              : Center(
                  child: Text('No content',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
    );
  }
}

class PageEditScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String? pageId;
  final String initialName;
  final String initialHtml;

  const PageEditScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.pageId,
    required this.initialName,
    required this.initialHtml,
  });

  @override
  State<PageEditScreen> createState() => _PageEditScreenState();
}

class _PageEditScreenState extends State<PageEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  bool _saving = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    final markdown =
        widget.initialHtml.isNotEmpty ? htmlToMarkdown(widget.initialHtml) : '';
    _contentController = TextEditingController(text: markdown);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _insertFormatting(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    final selected = sel.textInside(text);
    final newText = '$prefix$selected$suffix';
    _contentController.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, newText),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length,
      ),
    );
  }

  void _insertPrefix(String prefix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    // Find start of current line
    int lineStart = sel.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final html = markdownToHtml(_contentController.text.trim());
      if (widget.pageId != null) {
        await PageService.updatePage(
          widget.workspaceSlug,
          widget.projectId,
          widget.pageId!,
          {
            'name': _nameController.text.trim(),
            'description_html': html,
          },
        );
      } else {
        await PageService.createPage(
          widget.workspaceSlug,
          widget.projectId,
          {
            'name': _nameController.text.trim(),
            'description_html': html,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        sayError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3EAppBar(
        title: widget.pageId != null ? 'Edit Page' : 'New Page',
        actions: [
          M3EAppBarAction(
            icon: _preview ? Icons.edit : Icons.preview,
            tooltip: _preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: _saving
                ? const M3ELoadingIndicator(size: 22)
                : M3EPressable(
                    pressedScale: 0.92,
                    onTap: _save,
                    // The pill is about 35dp tall and M3EPressable forwards an
                    // opaque hit test over exactly its child, so the hit area
                    // was the pill. Centring it in a 48dp box lifts the target
                    // to the minimum; the 56dp app bar already has the room,
                    // so nothing moves.
                    child: SizedBox(
                      height: kMinInteractiveDimension,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(M3EShape.full),
                          ),
                          child: Text(
                            'Save',
                            style:
                                M3EType.emphasized(theme.textTheme.labelLarge!)
                                    .copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Title and body are the same control at different heights: one
          // outline, one corner, one fill. The title used to be a borderless
          // 20pt line, which read as a heading rather than as something typable.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: M3ETextField(
              label: 'Page name',
              controller: _nameController,
            ),
          ),
          if (!_preview) _buildToolbar(theme),
          Expanded(
            child: _preview
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: _contentController.text,
                      selectable: true,
                    ),
                  )
                // The body grows with its content inside a scroll view rather
                // than being stretched to the viewport: a field forced to fill
                // the remaining height centres short text in the middle of it.
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: M3ETextField(
                      label: 'Page content',
                      hint: 'Write in markdown...',
                      controller: _contentController,
                      maxLines: null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      // 56 so each 40dp circle has room to breathe and still clears the 48dp
      // touch minimum. At the old 44 the buttons were clipped by the row.
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          M3EIconButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertFormatting('**', '**'),
          ),
          M3EIconButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertFormatting('*', '*'),
          ),
          M3EIconButton(
            icon: Icons.title,
            tooltip: 'Heading',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertPrefix('## '),
          ),
          M3EIconButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'List',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertPrefix('- '),
          ),
          M3EIconButton(
            icon: Icons.code,
            tooltip: 'Code',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertFormatting('`', '`'),
          ),
          M3EIconButton(
            icon: Icons.link,
            tooltip: 'Link',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertFormatting('[', '](url)'),
          ),
          M3EIconButton(
            icon: Icons.format_quote,
            tooltip: 'Quote',
            size: M3EIconButtonSize.small,
            onPressed: () => _insertPrefix('> '),
          ),
        ],
      ),
    );
  }
}
