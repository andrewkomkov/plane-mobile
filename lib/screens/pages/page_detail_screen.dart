import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/page_service.dart';
import '../../models/page.dart';

class PageDetailScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String pageId;
  final String pageName;

  const PageDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.pageId,
    required this.pageName,
  });

  @override
  State<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends State<PageDetailScreen> {
  PlanePage? _page;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await PageService.getPage(
          widget.workspaceSlug, widget.projectId, widget.pageId);
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPage() async {
    if (_page == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          pageId: widget.pageId,
          initialName: _page!.name,
          initialHtml: _page!.descriptionHtml ?? '',
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_page?.name ?? widget.pageName),
        actions: [
          if (_page != null && !_page!.isLocked)
            IconButton(icon: const Icon(Icons.edit), onPressed: _editPage),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _page?.descriptionHtml != null && _page!.descriptionHtml!.isNotEmpty
              ? WebViewWidget(
                  controller: WebViewController()
                    ..setBackgroundColor(Theme.of(context).scaffoldBackgroundColor)
                    ..loadHtmlString(_wrapHtml(_page!.descriptionHtml!)),
                )
              : const Center(child: Text('No content')),
    );
  }

  String _wrapHtml(String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? '#1a1a1a' : '#fff';
    final fg = isDark ? '#e0e0e0' : '#333';
    return '''
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: -apple-system, sans-serif; padding: 16px; font-size: 15px; color: $fg; background: $bg; line-height: 1.6; }
h1,h2,h3 { margin-top: 16px; }
code { background: ${isDark ? '#333' : '#f0f0f0'}; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
pre { background: ${isDark ? '#333' : '#f0f0f0'}; padding: 12px; border-radius: 8px; overflow-x: auto; }
ul,ol { padding-left: 20px; }
</style>
</head><body>$body</body></html>''';
  }
}

class PageEditScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String pageId;
  final String initialName;
  final String initialHtml;

  const PageEditScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.pageId,
    required this.initialName,
    required this.initialHtml,
  });

  @override
  State<PageEditScreen> createState() => _PageEditScreenState();
}

class _PageEditScreenState extends State<PageEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _htmlController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _htmlController = TextEditingController(text: widget.initialHtml);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _htmlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PageService.updatePage(
        widget.workspaceSlug,
        widget.projectId,
        widget.pageId,
        {
          'name': _nameController.text.trim(),
          'description_html': _htmlController.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Page'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Page name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _htmlController,
                decoration: const InputDecoration(
                  labelText: 'Content (HTML)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
