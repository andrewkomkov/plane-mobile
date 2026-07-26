import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/view_service.dart';
import '../../models/favorite.dart';
import '../../models/view.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../utils/time_ago.dart';
import 'view_detail_screen.dart';

class ViewListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const ViewListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
  });

  @override
  ConsumerState<ViewListScreen> createState() => _ViewListScreenState();
}

class _ViewListScreenState extends ConsumerState<ViewListScreen>
    with AutomaticKeepAliveClientMixin {
  List<PlaneView> _views = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // One read per workspace, shared with every other list that draws a star.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final views =
          await ViewService.getViews(widget.workspaceSlug, widget.projectId);
      setState(() {
        _views = views;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createView() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New View'),
          content: M3ETextField(
            label: 'View name',
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Create')),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      try {
        // `filters`, not `query_data`: there is no such field on `IssueView`.
        // The serializer takes `filters` and compiles it into the read-only
        // `query` itself, and drops any key it does not recognise without
        // complaining — so a view created with `query_data` would silently
        // save no filters at all.
        await ViewService.createView(
          widget.workspaceSlug,
          widget.projectId,
          {'name': name, 'filters': <String, dynamic>{}},
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteView(PlaneView view) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete View'),
        content: Text('Delete "${view.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ViewService.deleteView(
            widget.workspaceSlug, widget.projectId, view.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingStateWidget();
    if (_error != null) {
      return ErrorStateWidget(message: 'Failed to load views', onRetry: _load);
    }

    final views = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.view, _views, (v) => v.id);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: views.isEmpty
            ? ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                const Center(
                  child: EmptyStateWidget(
                    message: 'No saved views',
                    icon: Icons.view_list_outlined,
                    subtitle: 'Create a view to save filter presets',
                  ),
                ),
              ])
            : ListView.builder(
                itemCount: views.length,
                itemBuilder: (ctx, i) {
                  final view = views[i];
                  final subtitle =
                      view.description ?? timeAgoShort(view.updatedAt);
                  return PlaneRow(
                    icon: Icons.view_list_outlined,
                    title: view.name,
                    subtitle: subtitle,
                    semanticLabel: '${view.name}, view, $subtitle',
                    // Named per view so repeated rows stay distinguishable to
                    // external automation. Both sit in `trailing` rather than
                    // inside the row so that they keep those names — the row's
                    // own label replaces the semantics of everything it wraps.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FavoriteToggle(
                          workspaceSlug: widget.workspaceSlug,
                          entity: FavoriteEntity.view,
                          entityId: view.id,
                          entityName: view.name,
                          projectId: widget.projectId,
                        ),
                        M3EIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete view ${view.name}',
                          size: M3EIconButtonSize.small,
                          onPressed: () => _deleteView(view),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewDetailScreen(
                            workspaceSlug: widget.workspaceSlug,
                            projectId: widget.projectId,
                            view: view,
                          ),
                        ),
                      );
                      _load();
                    },
                  );
                },
              ),
      ),
    );
  }
}
