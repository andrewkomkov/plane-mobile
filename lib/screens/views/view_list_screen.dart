import 'package:flutter/material.dart';
import '../../utils/say.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/view_service.dart';
import '../../models/favorite.dart';
import '../../models/view.dart';
import '../../providers/favorites_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/time_ago.dart';
import 'view_detail_screen.dart';

class ViewListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// Whether the signed-in user may create a view here. Resolved by
  /// `ProjectScreen` against the caller's project role; false until it lands,
  /// so the control never appears for someone the server would refuse.
  final bool canCreate;

  const ViewListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.canCreate = false,
  });

  @override
  ConsumerState<ViewListScreen> createState() => ViewListScreenState();
}

/// Public so `ProjectScreen` can start the create flow through a [GlobalKey].
class ViewListScreenState extends ConsumerState<ViewListScreen>
    with AutomaticKeepAliveClientMixin {
  List<PlaneView> _views = [];
  bool _initialLoading = true;
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
    setState(() => _error = null);
    try {
      final views =
          await ViewService.getViews(widget.workspaceSlug, widget.projectId);
      if (!mounted) return;
      setState(() {
        _views = views;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeApiError(e, fallback: 'Could not load views');
        _initialLoading = false;
      });
    }
  }

  /// Opens the "new view" form.
  ///
  /// The one entry point, called from the project screen's primary action and
  /// from the empty state below. Does nothing when the caller's role would be
  /// refused — the controls are already hidden in that case, and this is the
  /// second lock on the same door.
  Future<void> startCreate() async {
    if (!widget.canCreate) return;
    await _createView();
  }

  Future<void> _createView() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New view'),
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
          sayError(context,
              describeApiError(e, fallback: 'Could not create the view'));
        }
      }
    }
  }

  Future<void> _deleteView(PlaneView view) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete view',
      message: 'Delete "${view.name}"? The filters it saves are lost.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ViewService.deleteView(
          widget.workspaceSlug, widget.projectId, view.id);
      _load();
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not delete the view'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // A skeleton, not a spinner: the three sibling tabs on this screen all show
    // one, and this list resolves into rows of the same shape.
    if (_initialLoading && _views.isEmpty) {
      return const ProjectListSkeleton();
    }

    final views = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.view, _views, (v) => v.id);

    return Scaffold(
      body: Column(
        children: [
          // Views have no archive, so the count travels alone — but it is the
          // same header the three sibling tabs carry, which is the point.
          ListCountHeader(count: views.length, singular: 'view'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(views),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<PlaneView> views) {
    // Guarded on emptiness like the three sibling tabs: a refresh that fails
    // with rows already on screen should leave the rows, and the
    // RefreshIndicator, where they are.
    if (_error != null && views.isEmpty) {
      return ErrorStateWidget(message: _error, onRetry: _load);
    }
    if (views.isEmpty) {
      return ScrollableEmptyState(
        padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
        message: 'No saved views',
        icon: Icons.view_list_outlined,
        subtitle: widget.canCreate
            ? 'A view saves a set of filters to come back to'
            : 'Views shared with the project appear here',
        action: widget.canCreate
            ? FilledButton.tonalIcon(
                onPressed: startCreate,
                icon: const Icon(Icons.add),
                label: const Text('New view'),
              )
            : null,
      );
    }
    return ListView.builder(
      // Without this a list too short to scroll cannot be pulled, so the
      // RefreshIndicator wrapping it never fires.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
      itemCount: views.length,
      itemBuilder: (ctx, i) => _viewRow(views[i]),
    );
  }

  Widget _viewRow(PlaneView view) {
    final subtitle = view.description ?? timeAgoShort(view.updatedAt);
    return PlaneRow(
      icon: Icons.view_list_outlined,
      title: view.name,
      subtitle: subtitle,
      semanticLabel: '${view.name}, view, $subtitle',
      // Named per view so repeated rows stay distinguishable to external
      // automation. Both sit in `trailing` rather than inside the row so that
      // they keep those names — the row's own label replaces the semantics of
      // everything it wraps.
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
        if (!mounted) return;
        _load();
      },
    );
  }
}
