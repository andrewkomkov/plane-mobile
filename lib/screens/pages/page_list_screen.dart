import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/page.dart';
import '../../services/page_service.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/plane_row.dart';
import 'page_detail_screen.dart';

class PageListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const PageListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
  });

  @override
  ConsumerState<PageListScreen> createState() => _PageListScreenState();
}

class _PageListScreenState extends ConsumerState<PageListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _initialLoading = true;
  String? _error;

  /// Whether the list is showing the archive instead of the live pages.
  bool _showArchived = false;

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  /// Everything the server sent, live and archived together.
  ///
  /// Pages are the odd one out: cycles and modules have a separate archive
  /// endpoint because their own lists exclude archived rows, but `PageViewSet`
  /// never filters on `archived_at`, so one request already carries both. The
  /// split is therefore done here rather than with a second call.
  List<PlanePage> get _allPages =>
      _cache.getPages(widget.workspaceSlug, widget.projectId) ?? [];

  List<PlanePage> get _livePages =>
      _allPages.where((p) => p.archivedAt == null).toList();

  List<PlanePage> get _archivedPages =>
      _allPages.where((p) => p.archivedAt != null).toList();

  List<PlanePage> get _pages => _showArchived ? _archivedPages : _livePages;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await _cache.loadPages(widget.workspaceSlug, widget.projectId,
          force: true);
      if (mounted) setState(() => _initialLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _createPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          initialName: '',
          initialHtml: '',
        ),
      ),
    );
    if (result == true) {
      _cache.invalidatePages(widget.workspaceSlug, widget.projectId);
      _load();
    }
  }

  Future<void> _confirmUnarchive(PlanePage page) async {
    final name = page.name.isEmpty ? 'Untitled' : page.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore page'),
        content: Text('Move "$name" back into the project pages?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PageService.unarchivePage(
          widget.workspaceSlug, widget.projectId, page.id);
      _cache.invalidatePages(widget.workspaceSlug, widget.projectId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name restored')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore page: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_initialLoading && _allPages.isEmpty) {
      return const ProjectListSkeleton();
    }

    return Scaffold(
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final count = _pages.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Text('$count ${count == 1 ? 'page' : 'pages'}',
              style: theme.textTheme.bodySmall),
          const Spacer(),
          ArchiveToggle(
            showArchived: _showArchived,
            entityPlural: 'pages',
            onChanged: (v) => setState(() => _showArchived = v),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _allPages.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load pages', onRetry: _load);
    }
    final pages = _pages;
    if (pages.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: _showArchived
              ? const EmptyStateWidget(
                  message: 'No archived pages',
                  icon: Icons.inventory_2_outlined,
                  subtitle:
                      'Pages archived from here or from the web appear here',
                )
              : const EmptyStateWidget(
                  message: 'No pages',
                  icon: Icons.description_outlined,
                  subtitle: 'Create a page to get started',
                ),
        ),
      ]);
    }
    return ListView.builder(
      itemCount: pages.length,
      itemBuilder: (ctx, i) => _pageRow(pages[i]),
    );
  }

  /// Archived reads through the same slots as everywhere else: the archive
  /// glyph in the leading position, the archive date on the subtitle line, and
  /// restore in the trailing slot, which keeps its own semantics node.
  Widget _pageRow(PlanePage page) {
    final name = page.name.isEmpty ? 'Untitled' : page.name;
    final archived = page.archivedAt != null;

    return PlaneRow(
      icon: archived
          ? Icons.inventory_2_outlined
          : (page.isLocked ? Icons.lock : Icons.description_outlined),
      title: name,
      subtitle: archived
          ? archivedOnLabel(page.archivedAt)
          : _formatDate(page.updatedAt),
      // The lock is drawn, so it has to be said: the row's label
      // replaces everything under it.
      semanticLabel: [
        name,
        if (archived) archivedOnLabel(page.archivedAt),
        if (page.isLocked) 'locked',
        'updated ${_formatDate(page.updatedAt)}',
      ].join(', '),
      trailing: archived
          ? M3EIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Restore page $name',
              size: M3EIconButtonSize.small,
              onPressed: () => _confirmUnarchive(page),
            )
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PageDetailScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.projectId,
              pageId: page.id,
              pageName: page.name,
            ),
          ),
        );
        if (!mounted) return;
        _cache.invalidatePages(widget.workspaceSlug, widget.projectId);
        _load();
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
