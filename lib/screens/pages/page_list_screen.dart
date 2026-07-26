import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../models/page.dart';
import '../../widgets/loading_state.dart';
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

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  List<PlanePage> get _pages =>
      _cache.getPages(widget.workspaceSlug, widget.projectId) ?? [];

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_initialLoading && _pages.isEmpty) {
      return const ProjectListSkeleton();
    }
    if (_error != null && _pages.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load pages', onRetry: _load);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _pages.isEmpty
            ? ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                const Center(
                  child: EmptyStateWidget(
                    message: 'No pages',
                    icon: Icons.description_outlined,
                    subtitle: 'Create a page to get started',
                  ),
                ),
              ])
            : ListView.builder(
                itemCount: _pages.length,
                itemBuilder: (ctx, i) {
                  final page = _pages[i];
                  final name = page.name.isEmpty ? 'Untitled' : page.name;
                  return PlaneRow(
                    icon:
                        page.isLocked ? Icons.lock : Icons.description_outlined,
                    title: name,
                    subtitle: _formatDate(page.updatedAt),
                    // The lock is drawn, so it has to be said: the row's label
                    // replaces everything under it.
                    semanticLabel: [
                      name,
                      if (page.isLocked) 'locked',
                      'updated ${_formatDate(page.updatedAt)}',
                    ].join(', '),
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
                      _cache.invalidatePages(
                          widget.workspaceSlug, widget.projectId);
                      _load();
                    },
                  );
                },
              ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
