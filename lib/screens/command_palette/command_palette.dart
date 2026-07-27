import 'dart:async';
import '../../widgets/loading_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/bottom_sheet_picker.dart';
import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/search_service.dart';
import '../../services/project_service.dart';
import '../../models/project.dart';
import '../../utils/search_result_route.dart';
import '../../screens/issues/issue_create_screen.dart';
import '../../screens/project/project_screen.dart';

class CommandPalette extends ConsumerStatefulWidget {
  final String workspaceSlug;

  const CommandPalette({super.key, required this.workspaceSlug});

  static Future<void> show(BuildContext context, String workspaceSlug) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // No `backgroundColor: Colors.transparent` and no hand-rolled surface:
      // this sheet and the intake sheet both did that and landed on two
      // different colours, neither of them the themed one.
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => _CommandPaletteBody(
          workspaceSlug: workspaceSlug,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  @override
  Widget build(BuildContext context) {
    return _CommandPaletteBody(workspaceSlug: widget.workspaceSlug);
  }
}

class _CommandPaletteBody extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final ScrollController? scrollController;

  const _CommandPaletteBody({
    required this.workspaceSlug,
    this.scrollController,
  });

  @override
  ConsumerState<_CommandPaletteBody> createState() =>
      _CommandPaletteBodyState();
}

class _CommandPaletteBodyState extends ConsumerState<_CommandPaletteBody> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_CommandItem> _quickActions = [];
  List<_CommandItem> _searchResults = [];
  bool _loading = false;
  List<Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _quickActions = [
      _CommandItem(
        icon: Icons.add,
        label: 'Create issue',
        type: _CommandType.action,
        onTap: _createIssue,
      ),
      _CommandItem(
        icon: Icons.swap_horiz,
        label: 'Switch project',
        type: _CommandType.action,
        onTap: _switchProject,
      ),
    ];
    _loadProjects();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      _projects = await ProjectService.getProjects(widget.workspaceSlug);
    } catch (_) {}
  }

  void _createIssue() {
    Navigator.pop(context);
    if (_projects.isEmpty) return;
    // Use first project as default
    final project = _projects.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: project.id,
          states: const {},
        ),
      ),
    );
  }

  void _switchProject() async {
    Navigator.pop(context);
    if (_projects.isEmpty) return;
    final id = await BottomSheetPicker.show<String>(
      context: context,
      title: 'Switch project',
      items: [
        for (final p in _projects)
          BottomSheetPickerItem(
            value: p.id,
            label: p.name,
            subtitle: p.identifier,
            icon: Icons.bolt_outlined,
          ),
      ],
    );
    final selected = _projects.where((p) => p.id == id).firstOrNull;
    if (selected != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectScreen(
            workspaceSlug: widget.workspaceSlug,
            project: selected,
          ),
        ),
      );
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results =
          await SearchService.searchAll(widget.workspaceSlug, query);
      final items = <_CommandItem>[];
      for (final entry in results.entries) {
        for (final item in entry.value) {
          items.add(_CommandItem(
            icon: _iconForType(entry.key),
            label: (item['name'] ?? item['title'] ?? '').toString(),
            subtitle: entry.key,
            type: _CommandType.result,
            // Dismiss the palette first, then route: the result opens over the
            // screen that launched the palette, not over the palette itself.
            onTap: () {
              Navigator.pop(context);
              openSearchResult(
                context,
                workspaceSlug: widget.workspaceSlug,
                type: entry.key,
                item: item,
              );
            },
          ));
        }
      }
      // Also filter quick actions by query
      final matchingProjects = _projects
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.identifier.toLowerCase().contains(query.toLowerCase()))
          .map((p) => _CommandItem(
                icon: Icons.bolt_outlined,
                label: p.name,
                subtitle: 'Project',
                type: _CommandType.result,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectScreen(
                        workspaceSlug: widget.workspaceSlug,
                        project: p,
                      ),
                    ),
                  );
                },
              ));
      items.addAll(matchingProjects);
      setState(() {
        _searchResults = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'issues':
        return Icons.radio_button_unchecked;
      case 'projects':
        return Icons.bolt_outlined;
      case 'pages':
        return Icons.description_outlined;
      case 'cycles':
        return Icons.loop;
      case 'modules':
        return Icons.view_module_outlined;
      default:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSearch = _controller.text.length >= 2;
    final items = showSearch ? _searchResults : _quickActions;
    final filteredActions = showSearch
        ? _quickActions
            .where((a) =>
                a.label.toLowerCase().contains(_controller.text.toLowerCase()))
            .toList()
        : <_CommandItem>[];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(M3EShape.extraLargeIncreased)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No drag handle here: `bottomSheetTheme` already draws one, and
          // this was one of the four sheets painting a second underneath it.
          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: M3ETextField(
              label: 'Command or search',
              hint: 'Type a command or search...',
              compact: true,
              prefixIcon: Icons.search,
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: M3ELoadingIndicator(size: 20)),
            ),
          // Quick actions header
          if (!showSearch) const SectionHeader(label: 'Quick actions'),
          // Items
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                if (showSearch && filteredActions.isNotEmpty) ...[
                  const SectionHeader(label: 'Actions'),
                  ...filteredActions.map(_buildItem),
                  if (items.isNotEmpty)
                    SectionHeader(label: 'Results', count: items.length),
                ],
                ...items.map(_buildItem),
                if (showSearch && items.isEmpty && !_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyStateWidget(
                      message: 'No results',
                      icon: Icons.search_off,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_CommandItem item) {
    return SheetOptionRow<String>(
      item: BottomSheetPickerItem(
        value: item.label,
        label: item.label,
        subtitle: item.subtitle,
        icon: item.icon,
      ),
      selected: false,
      onTap: item.onTap,
    );
  }
}

enum _CommandType { action, result }

class _CommandItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final _CommandType type;
  final VoidCallback onTap;

  _CommandItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.type,
    required this.onTap,
  });
}
