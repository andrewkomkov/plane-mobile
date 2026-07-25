import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/view_service.dart';
import '../../models/view.dart';
import '../../widgets/loading_state.dart';
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
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final views = await ViewService.getViews(
          widget.workspaceSlug, widget.projectId);
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
                onPressed: () =>
                    Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Create')),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      try {
        await ViewService.createView(
          widget.workspaceSlug,
          widget.projectId,
          {'name': name, 'query_data': {}},
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
      return ErrorStateWidget(
          message: 'Failed to load views', onRetry: _load);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _views.isEmpty
            ? ListView(children: [
                SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3),
                const Center(
                  child: EmptyStateWidget(
                    message: 'No saved views',
                    icon: Icons.view_list_outlined,
                    subtitle: 'Create a view to save filter presets',
                  ),
                ),
              ])
            : ListView.builder(
                itemCount: _views.length,
                itemBuilder: (ctx, i) {
                  final view = _views[i];
                  final secondary =
                      Theme.of(ctx).colorScheme.onSurfaceVariant;
                  return ListTile(
                    leading:
                        Icon(Icons.view_list_outlined, color: secondary),
                    title: Text(view.name),
                    subtitle: Text(
                      view.description ?? timeAgoShort(view.updatedAt),
                      style: TextStyle(fontSize: 12, color: secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Named per view so repeated rows stay distinguishable to
                    // external automation.
                    trailing: M3EIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete view ${view.name}',
                      size: M3EIconButtonSize.small,
                      onPressed: () => _deleteView(view),
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
