import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../providers/favorites_provider.dart';
import '../../models/favorite.dart';
import '../../models/page.dart';
import '../../services/page_service.dart';
import '../../utils/api_error.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/plane_row.dart';
import '../project/project_screen.dart' show kProjectListBottomInset;
import 'page_detail_screen.dart';

class PageListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// Whether the signed-in user may create a page here. Resolved by
  /// `ProjectScreen` against the caller's project role; false until it lands,
  /// so the control never appears for someone the server would refuse.
  final bool canCreate;

  const PageListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.canCreate = false,
  });

  @override
  ConsumerState<PageListScreen> createState() => PageListScreenState();
}

/// Public so `ProjectScreen` can start the create flow through a [GlobalKey].
class PageListScreenState extends ConsumerState<PageListScreen>
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
    // One read per workspace, shared with every other list that draws a star.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
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

  /// Opens the "new page" editor.
  ///
  /// The one entry point, called from the project screen's primary action and
  /// from the empty state below. Does nothing when the caller's role would be
  /// refused — the controls are already hidden in that case, and this is the
  /// second lock on the same door.
  Future<void> startCreate() async {
    if (!widget.canCreate) return;
    await _createPage();
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
          SnackBar(
            content: Text(
                describeApiError(e, fallback: 'Could not restore the page')),
          ),
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
    return ListCountHeader(
      count: _pages.length,
      singular: 'page',
      trailing: ArchiveToggle(
        showArchived: _showArchived,
        entityPlural: 'pages',
        onChanged: (v) => setState(() => _showArchived = v),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _allPages.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load pages', onRetry: _load);
    }
    final pages = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.page, _pages, (p) => p.id);
    if (pages.isEmpty) {
      if (_showArchived) {
        return const ScrollableEmptyState(
          padding: EdgeInsets.only(bottom: kProjectListBottomInset),
          message: 'No archived pages',
          icon: Icons.inventory_2_outlined,
          subtitle: 'Pages archived from here or from the web appear here',
        );
      }
      return ScrollableCenter(
        padding: const EdgeInsets.only(bottom: kProjectListBottomInset),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyStateWidget(
              message: 'No pages',
              icon: Icons.description_outlined,
              // The old copy said "Create a page to get started" with nothing
              // to tap. It now either has a button under it or, for a guest,
              // says nothing it cannot back up.
              subtitle: widget.canCreate
                  ? 'Notes, specs and docs that live with the project'
                  : 'Pages written by the team appear here',
            ),
            if (widget.canCreate) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: startCreate,
                icon: const Icon(Icons.add),
                label: const Text('New page'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      // Without this a list too short to scroll cannot be pulled, so the
      // RefreshIndicator wrapping it never fires.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: kProjectListBottomInset),
      itemCount: pages.length,
      itemBuilder: (ctx, i) => _pageRow(pages[i]),
    );
  }

  /// Archived reads through the same slots as everywhere else: the archive
  /// glyph in the leading position, the archive date on the subtitle line, and
  /// restore next to the favourite star in the trailing slot, which is the one
  /// slot that keeps its own semantics node.
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteToggle(
            workspaceSlug: widget.workspaceSlug,
            entity: FavoriteEntity.page,
            entityId: page.id,
            entityName: name,
            projectId: widget.projectId,
          ),
          if (archived)
            M3EIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Restore page $name',
              size: M3EIconButtonSize.small,
              onPressed: () => _confirmUnarchive(page),
            ),
        ],
      ),
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
