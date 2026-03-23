import 'package:flutter/material.dart';
import '../../services/page_service.dart';
import '../../models/page.dart';
import 'page_detail_screen.dart';

class PageListScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const PageListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
  });

  @override
  State<PageListScreen> createState() => _PageListScreenState();
}

class _PageListScreenState extends State<PageListScreen>
    with AutomaticKeepAliveClientMixin {
  List<PlanePage> _pages = [];
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
      final pages =
          await PageService.getPages(widget.workspaceSlug, widget.projectId);
      setState(() {
        _pages = pages;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createPage() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Page'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Page name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Create')),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      await PageService.createPage(
        widget.workspaceSlug,
        widget.projectId,
        {'name': name, 'description_html': '<p></p>'},
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _pages.isEmpty
            ? const Center(child: Text('No pages'))
            : ListView.builder(
                itemCount: _pages.length,
                itemBuilder: (ctx, i) {
                  final page = _pages[i];
                  return ListTile(
                    leading: Icon(
                      page.isLocked ? Icons.lock : Icons.description,
                      color: Colors.grey[600],
                    ),
                    title: Text(page.name.isEmpty ? 'Untitled' : page.name),
                    subtitle: Text(
                      _formatDate(page.updatedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                      _load();
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPage,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
