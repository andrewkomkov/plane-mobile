import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_navbar.dart';
import '../issues/issues_tab_screen.dart';
import '../issues/issue_create_screen.dart';
import '../pages/page_list_screen.dart';
import '../modules/module_list_screen.dart';
import '../cycles/cycle_list_screen.dart';
import '../views/view_list_screen.dart';
import '../search/search_screen.dart';
class ProjectScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final Project project;

  const ProjectScreen(
      {super.key, required this.workspaceSlug, required this.project});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  int _tab = 0;

  static const _navItems = [
    NavItem(
        icon: Icons.list_alt_outlined,
        activeIcon: Icons.list_alt,
        label: 'Issues'),
    NavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Pages'),
    NavItem(
        icon: Icons.view_module_outlined,
        activeIcon: Icons.view_module,
        label: 'Modules'),
    NavItem(
        icon: Icons.visibility_outlined,
        activeIcon: Icons.visibility,
        label: 'Views'),
    NavItem(
        icon: Icons.loop_outlined,
        activeIcon: Icons.loop,
        label: 'Cycles'),
  ];

  void _createIssue() async {
    final states = ref.read(dataCacheProvider)
        .getStates(widget.workspaceSlug, widget.project.id) ?? {};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.project.id,
          states: states,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PlaneTheme.background.withValues(alpha: 0.80),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22, color: PlaneTheme.primaryContainer),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: PlaneTheme.onSurface,
              ),
            ),
            Text(
              widget.project.identifier,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Colors.white.withValues(alpha: 0.40),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square, size: 20, color: PlaneTheme.primaryContainer),
            onPressed: _createIssue,
          ),
        ],
      ),
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          IssuesTabScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              projectIdentifier: widget.project.identifier),
          PageListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          ModuleListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          ViewListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          CycleListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        items: _navItems,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        showSearch: true,
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(
                workspaceSlug: widget.workspaceSlug,
                autoFocus: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
