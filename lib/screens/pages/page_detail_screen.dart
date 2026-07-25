import 'package:flutter/material.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/page_service.dart';
import '../../models/page.dart';
import '../../utils/html_to_markdown.dart';
import '../../utils/markdown_to_html.dart';
import '../../widgets/loading_state.dart';

class PageDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PageDetailScreen> createState() =>
      _PageDetailScreenState();
}

class _PageDetailScreenState extends ConsumerState<PageDetailScreen> {
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3EAppBar(
        title: _page?.name ?? widget.pageName,
        actions: [
          if (_page != null && !_page!.isLocked)
            M3EAppBarAction(
                icon: Icons.edit,
                tooltip: 'Edit page',
                emphasized: true,
                onPressed: _editPage),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _page?.descriptionHtml != null &&
                  _page!.descriptionHtml!.isNotEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownBody(
                    data: htmlToMarkdown(_page!.descriptionHtml!),
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: theme.colorScheme.onSurface),
                      h1: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface),
                      h2: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface),
                      h3: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface),
                      code: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.08),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(M3EShape.large),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 3)),
                      ),
                      blockquotePadding:
                          const EdgeInsets.fromLTRB(12, 4, 0, 4),
                      listBullet: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.onSurface),
                    ),
                    selectable: true,
                  ),
                )
              : Center(
                  child: Text('No content',
                      style: TextStyle(
                          fontSize: 15,
                          color:
                              theme.colorScheme.onSurfaceVariant)),
                ),
    );
  }
}

class PageEditScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String? pageId;
  final String initialName;
  final String initialHtml;

  const PageEditScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.pageId,
    required this.initialName,
    required this.initialHtml,
  });

  @override
  State<PageEditScreen> createState() => _PageEditScreenState();
}

class _PageEditScreenState extends State<PageEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  bool _saving = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    final markdown = widget.initialHtml.isNotEmpty
        ? htmlToMarkdown(widget.initialHtml)
        : '';
    _contentController = TextEditingController(text: markdown);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _insertFormatting(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    final selected = sel.textInside(text);
    final newText = '$prefix$selected$suffix';
    _contentController.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, newText),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length,
      ),
    );
  }

  void _insertPrefix(String prefix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    // Find start of current line
    int lineStart = sel.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final html = markdownToHtml(_contentController.text.trim());
      if (widget.pageId != null) {
        await PageService.updatePage(
          widget.workspaceSlug,
          widget.projectId,
          widget.pageId!,
          {
            'name': _nameController.text.trim(),
            'description_html': html,
          },
        );
      } else {
        await PageService.createPage(
          widget.workspaceSlug,
          widget.projectId,
          {
            'name': _nameController.text.trim(),
            'description_html': html,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3EAppBar(
        title: widget.pageId != null ? 'Edit Page' : 'New Page',
        actions: [
          M3EAppBarAction(
            icon: _preview ? Icons.edit : Icons.preview,
            tooltip: _preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: _saving
                ? const M3ELoadingIndicator(size: 22)
                : M3EPressable(
                    pressedScale: 0.92,
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(M3EShape.full),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  hintText: 'Page name',
                  border: InputBorder.none),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(),
          if (!_preview) _buildToolbar(theme),
          Expanded(
            child: _preview
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: _contentController.text,
                      selectable: true,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: 'Write in markdown...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onTap: () => _insertFormatting('**', '**'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onTap: () => _insertFormatting('*', '*'),
          ),
          _ToolbarButton(
            icon: Icons.title,
            tooltip: 'Heading',
            onTap: () => _insertPrefix('## '),
          ),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'List',
            onTap: () => _insertPrefix('- '),
          ),
          _ToolbarButton(
            icon: Icons.code,
            tooltip: 'Code',
            onTap: () => _insertFormatting('`', '`'),
          ),
          _ToolbarButton(
            icon: Icons.link,
            tooltip: 'Link',
            onTap: () => _insertFormatting('[', '](url)'),
          ),
          _ToolbarButton(
            icon: Icons.format_quote,
            tooltip: 'Quote',
            onTap: () => _insertPrefix('> '),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // A tooltip is exposed to Android as tooltipText, not as the node's
      // content description, so the label has to ride on the icon itself for
      // `uiautomator dump` to see it.
      icon: Icon(icon, size: 20, semanticLabel: tooltip),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 36),
    );
  }
}
