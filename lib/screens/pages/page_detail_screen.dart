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
        widget.workspaceSlug,
        widget.projectId,
        widget.pageId,
      );
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_page?.name ?? widget.pageName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _page?.descriptionHtml != null
              ? WebViewWidget(
                  controller: WebViewController()
                    ..loadHtmlString(
                      '<html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{font-family:sans-serif;padding:16px;font-size:15px;color:#333;}</style></head><body>${_page!.descriptionHtml!}</body></html>',
                    ),
                )
              : const Center(child: Text('No content')),
    );
  }
}
