import 'package:flutter/material.dart';
import '../../utils/say.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite.dart';
import '../../models/workspace_rollup.dart';
import '../../providers/favorites_provider.dart';
import '../../services/workspace_rollup_service.dart';
import '../../utils/api_error.dart';
import '../../utils/time_ago.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/plane_row.dart';
import 'workspace_issues_screen.dart';

/// Saved views that span the workspace instead of one project.
///
/// Plane stores both kinds in the same table and tells them apart by whether
/// `project` is set; the workspace list filters on `project__isnull=True`, so
/// nothing here overlaps with the per-project Views tab.
///
/// Creating one is deliberately not offered. A view is its filters, and a view
/// created with none is a saved list of everything — which is the screen the
/// menu already has. Building the filter editor that would make creation
/// worthwhile is a bigger job than reading the route.
class WorkspaceViewsScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;

  const WorkspaceViewsScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<WorkspaceViewsScreen> createState() =>
      _WorkspaceViewsScreenState();
}

class _WorkspaceViewsScreenState extends ConsumerState<WorkspaceViewsScreen> {
  List<WorkspaceView> _views = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
    try {
      final views = await WorkspaceRollupService.getViews(widget.workspaceSlug);
      if (!mounted) return;
      setState(() {
        _views = views;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(WorkspaceView view) async {
    // The dialog this replaces styled "Delete" exactly like "Cancel" — same
    // colour, same weight — for an irreversible action. `confirmDestructive` is
    // the one shape, and it puts the destructive button in the error role.
    final ok = await confirmDestructive(
      context,
      title: 'Delete view',
      message: 'Delete "${view.name}"? The work items it lists are not '
          'affected, but the saved filters are gone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;

    try {
      await WorkspaceRollupService.deleteView(widget.workspaceSlug, view.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      // The server answers 400, not 403, when the caller is neither the
      // workspace admin nor the view's owner, so a refusal reaches here as an
      // ordinary error and has to be shown rather than swallowed.
      sayError(
        context,
        describeApiError(e, fallback: 'Could not delete view'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _views.length;
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Workspace views',
        subtitle: _loading ? null : ListCountHeader.label(count, 'view'),
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load workspace views', onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _list()),
    );
  }

  Widget _list() {
    if (_views.isEmpty) {
      // The magic `MediaQuery.height * 0.25` spacer is gone; the shared helper
      // says what it was actually for, which is giving the list enough height
      // to be pulled.
      return const ScrollableEmptyState(
        message: 'No workspace views',
        icon: Icons.view_list_outlined,
        subtitle: 'Views saved across all projects appear here',
      );
    }

    // Starred views to the front, as the project-level views list does.
    final ordered = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.view, _views, (v) => v.id);

    return ListView.builder(
      // A short list still has to be draggable, or pull to refresh does
      // nothing on a workspace with two saved views.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: ordered.length,
      itemBuilder: (ctx, i) => _viewRow(ordered[i]),
    );
  }

  Widget _viewRow(WorkspaceView view) {
    // How many things the view narrows on. A count is the only honest summary
    // available without resolving every id in the filter map against a name.
    final filterCount =
        WorkspaceRollupService.filtersToQuery(view.filters).length;
    final subtitle = view.description ?? timeAgoShort(view.updatedAt);

    return PlaneRow(
      icon: Icons.view_list_outlined,
      title: view.name,
      subtitle: subtitle,
      semanticLabel: [
        view.name,
        'workspace view',
        if (view.isPrivate) 'private',
        if (view.isLocked) 'locked',
        if (filterCount > 0)
          '$filterCount ${filterCount == 1 ? 'filter' : 'filters'}',
        subtitle,
      ].join(', '),
      metadata: [
        if (view.isPrivate) const PlaneRowMeta(icon: Icons.lock_outline),
        if (filterCount > 0)
          PlaneRowMeta(
            icon: Icons.filter_alt_outlined,
            text: '$filterCount',
          ),
      ],
      // Both named per view so repeated rows stay distinguishable to external
      // automation, and both in `trailing`, the one slot outside the row's own
      // semantics node — inside it they would be swallowed by the row's label.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteToggle(
            workspaceSlug: widget.workspaceSlug,
            entity: FavoriteEntity.view,
            entityId: view.id,
            entityName: view.name,
            // No `projectId`: a workspace view is precisely the view that has
            // no project, which is how the list finds them
            // (`project__isnull=True`). The favourites row takes a null project.
          ),
          M3EIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete view ${view.name}',
            size: M3EIconButtonSize.small,
            onPressed: () => _delete(view),
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkspaceIssuesScreen(
            workspaceSlug: widget.workspaceSlug,
            view: view,
          ),
        ),
      ),
    );
  }
}
