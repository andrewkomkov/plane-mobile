import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workspace_rollup.dart';
import '../../services/workspace_rollup_service.dart';
import '../../utils/api_error.dart';
import '../../utils/time_ago.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete view'),
        content: Text('Delete "${view.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await WorkspaceRollupService.deleteView(widget.workspaceSlug, view.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      // The server answers 400, not 403, when the caller is neither the
      // workspace admin nor the view's owner, so a refusal reaches here as an
      // ordinary error and has to be shown rather than swallowed.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeApiError(e, fallback: 'Could not delete view'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _views.length;
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Workspace views',
        subtitle: _loading ? null : '$count ${count == 1 ? 'view' : 'views'}',
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
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: EmptyStateWidget(
            message: 'No workspace views',
            icon: Icons.view_list_outlined,
            subtitle: 'Views saved across all projects appear here',
          ),
        ),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _views.length,
      itemBuilder: (ctx, i) => _viewRow(_views[i]),
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
      // Named per view so repeated rows stay distinguishable to external
      // automation, and in `trailing` so it keeps a semantics node of its own.
      trailing: M3EIconButton(
        icon: Icons.delete_outline,
        tooltip: 'Delete view ${view.name}',
        size: M3EIconButtonSize.small,
        onPressed: () => _delete(view),
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
