import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../services/description_version_service.dart';
import '../../utils/html_to_markdown.dart';
import '../../utils/say.dart';
import '../../utils/time_ago.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/plane_row.dart';

/// What a work item's description used to say.
///
/// The activity feed already records *that* the description changed, and has
/// never recorded what it said. This is the only way back to a body that was
/// overwritten — which, on a screen where the description is one plain-text
/// field, is a real risk rather than a theoretical one.
///
/// Restoring is offered because a history you cannot act on is a curiosity.
/// It is a normal update to the work item, so it becomes the newest version in
/// turn and nothing is lost by trying it.
class DescriptionHistoryScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String issueId;

  /// Called with the chosen body when the user restores one, so the detail
  /// screen writes it through its own update path rather than this screen
  /// growing a second one.
  final Future<void> Function(String descriptionHtml) onRestore;

  const DescriptionHistoryScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.issueId,
    required this.onRestore,
  });

  @override
  State<DescriptionHistoryScreen> createState() =>
      _DescriptionHistoryScreenState();
}

class _DescriptionHistoryScreenState extends State<DescriptionHistoryScreen> {
  List<DescriptionVersion> _versions = [];
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
      final versions = await DescriptionVersionService.getVersions(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
      );
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the history';
      });
    }
  }

  Future<void> _open(DescriptionVersion version) async {
    // The listing omits the body — only the detail serialiser carries it — so
    // a version has to be fetched before it can be shown.
    DescriptionVersion full;
    try {
      full = await DescriptionVersionService.getVersion(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        version.id,
      );
    } catch (_) {
      if (mounted) say(context, 'Could not load that version');
      return;
    }
    if (!mounted) return;

    final body = full.descriptionHtml ?? '';
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('As of ${_when(version)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: body.trim().isEmpty
                ? Text('Empty', style: Theme.of(ctx).textTheme.bodyMedium)
                : MarkdownBody(data: htmlToMarkdown(body)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) return;

    final ok = await confirmDestructive(
      context,
      title: 'Restore this version?',
      message: 'The current description is replaced. It becomes a version in '
          'this list, so nothing is lost.',
      confirmLabel: 'Restore',
    );
    if (!ok || !mounted) return;

    try {
      await widget.onRestore(body);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) say(context, 'Could not restore it');
    }
  }

  static String _when(DescriptionVersion version) =>
      '${timeAgoShort(version.lastSavedAt)} ago';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const M3EAppBar(title: 'Description history'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ScrollableCenter(
                  child: ErrorStateWidget(message: _error, onRetry: _load),
                )
              : _versions.isEmpty
                  ? const ScrollableEmptyState(
                      message: 'No earlier versions',
                      icon: Icons.history,
                      subtitle:
                          'Plane records one each time the description is '
                          'edited. This work item has only ever had the one.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _versions.length,
                        itemBuilder: (ctx, i) {
                          final version = _versions[i];
                          return PlaneRow(
                            icon: Icons.history,
                            title: _when(version),
                            subtitle: i == 0
                                ? 'The version before the current one'
                                : null,
                            semanticLabel:
                                'Version from ${_when(version)}. Open it',
                            onTap: () => _open(version),
                          );
                        },
                      ),
                    ),
    );
  }
}
