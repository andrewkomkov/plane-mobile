import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/secure_storage.dart';
import '../../config/api_client.dart';
import '../../config/theme.dart';
import '../../services/project_service.dart';
import '../../services/issue_service.dart';
import '../../services/auth_service.dart';
import '../../models/project.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/user.dart';
import '../issues/issues_tab_screen.dart';
import '../issues/issue_detail_screen.dart';
import '../pages/page_list_screen.dart';
import '../modules/module_list_screen.dart';
import '../cycles/cycle_list_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _workspaceSlug = '';
  User? _user;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _workspaceSlug = await SecureStorage.getWorkspaceSlug() ?? '';
    try {
      _user = await AuthService.getCurrentUser();
    } catch (_) {}
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          InboxTab(workspaceSlug: _workspaceSlug),
          MyIssuesTab(workspaceSlug: _workspaceSlug),
          ProjectsTab(workspaceSlug: _workspaceSlug),
          MenuTab(workspaceSlug: _workspaceSlug, user: _user, onLogout: widget.onLogout),
          SearchScreen(workspaceSlug: _workspaceSlug),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.75),
              border: Border(top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
                width: 0.5,
              )),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavIcon(icon: Icons.inbox_outlined, activeIcon: Icons.inbox, index: 0, current: _currentTab, onTap: () => setState(() => _currentTab = 0)),
                    _NavIcon(icon: Icons.radio_button_unchecked, activeIcon: Icons.adjust, index: 1, current: _currentTab, onTap: () => setState(() => _currentTab = 1)),
                    _NavIcon(icon: Icons.bolt_outlined, activeIcon: Icons.bolt, index: 2, current: _currentTab, onTap: () => setState(() => _currentTab = 2)),
                    _NavIcon(icon: Icons.diamond_outlined, activeIcon: Icons.diamond, index: 3, current: _currentTab, onTap: () => setState(() => _currentTab = 3)),
                    _NavIcon(icon: Icons.search, activeIcon: Icons.search, index: 4, current: _currentTab, onTap: () => setState(() => _currentTab = 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inbox Tab ───
class InboxTab extends StatefulWidget {
  final String workspaceSlug;
  const InboxTab({super.key, required this.workspaceSlug});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> with AutomaticKeepAliveClientMixin {
  List<Issue> _recent = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.workspaceSlug.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Load issues from all projects, sorted by updated_at
      final projects = await ProjectService.getProjects(widget.workspaceSlug);
      final allIssues = <Issue>[];
      for (final p in projects.take(5)) {
        try {
          final result = await IssueService.getIssues(
            widget.workspaceSlug, p.id,
            orderBy: '-updated_at',
            perPage: 10,
          );
          allIssues.addAll(result['issues'] as List<Issue>);
        } catch (_) {}
      }
      allIssues.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _recent = allIssues.take(30).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_horiz, size: 20), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _recent.isEmpty
                  ? ListView(children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(child: Text('No recent activity',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                    ])
                  : ListView.separated(
                      itemCount: _recent.length,
                      separatorBuilder: (_, __) => Divider(indent: 16, endIndent: 16, height: 0.5),
                      itemBuilder: (ctx, i) {
                        final issue = _recent[i];
                        return _InboxRow(issue: issue);
                      },
                    ),
            ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final Issue issue;
  const _InboxRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(PlaneTheme.priorityIcon(issue.priority), size: 16,
                color: PlaneTheme.priorityColor(issue.priority)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 3),
                  Text(_timeAgo(issue.updatedAt),
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

// ─── My Issues Tab ───
class MyIssuesTab extends StatefulWidget {
  final String workspaceSlug;
  const MyIssuesTab({super.key, required this.workspaceSlug});

  @override
  State<MyIssuesTab> createState() => _MyIssuesTabState();
}

class _MyIssuesTabState extends State<MyIssuesTab> with AutomaticKeepAliveClientMixin {
  List<Issue> _issues = [];
  Map<String, IssueState> _allStates = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.workspaceSlug.isEmpty) return;
    setState(() => _loading = true);
    try {
      final projects = await ProjectService.getProjects(widget.workspaceSlug);
      final allIssues = <Issue>[];
      final allStates = <String, IssueState>{};
      for (final p in projects) {
        try {
          final states = await IssueService.getStates(widget.workspaceSlug, p.id);
          for (final s in states) {
            allStates[s.id] = s;
          }
          final result = await IssueService.getIssues(widget.workspaceSlug, p.id);
          allIssues.addAll(result['issues'] as List<Issue>);
        } catch (_) {}
      }
      setState(() {
        _issues = allIssues;
        _allStates = allStates;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Map<String, List<Issue>> get _grouped {
    final groups = <String, List<Issue>>{'started': [], 'unstarted': [], 'backlog': []};
    for (final issue in _issues) {
      final state = _allStates[issue.state];
      final group = state?.group ?? 'backlog';
      if (group == 'completed' || group == 'cancelled') continue;
      groups.putIfAbsent(group, () => []);
      groups[group]!.add(issue);
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  String _groupLabel(String g) {
    switch (g) {
      case 'started': return 'In Progress';
      case 'unstarted': return 'Todo';
      case 'backlog': return 'Backlog';
      default: return g;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My issues'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_horiz, size: 20), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildGroupedList(),
            ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = _grouped;
    if (grouped.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(child: Text('No open issues',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]);
    }

    final items = <Widget>[];
    for (final entry in grouped.entries) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(_groupLabel(entry.key),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PlaneTheme.stateGroupColor(entry.key),
            )),
      ));
      for (final issue in entry.value) {
        final state = _allStates[issue.state];
        items.add(InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(PlaneTheme.priorityIcon(issue.priority), size: 15,
                    color: PlaneTheme.priorityColor(issue.priority)),
                const SizedBox(width: 8),
                Icon(PlaneTheme.stateIcon(state?.group ?? 'backlog'), size: 15,
                    color: PlaneTheme.stateGroupColor(state?.group ?? 'backlog')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(issue.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ));
      }
    }

    return ListView(children: items);
  }
}

// ─── Projects Tab ───
class ProjectsTab extends StatefulWidget {
  final String workspaceSlug;
  const ProjectsTab({super.key, required this.workspaceSlug});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> with AutomaticKeepAliveClientMixin {
  List<Project> _projects = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.workspaceSlug.isEmpty) return;
    setState(() => _loading = true);
    try {
      final projects = await ProjectService.getProjects(widget.workspaceSlug);
      setState(() { _projects = projects; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_horiz, size: 20), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (ctx, i) {
                  final p = _projects[i];
                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(p.identifier,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary)),
                      ),
                    ),
                    title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProjectScreen(workspaceSlug: widget.workspaceSlug, project: p),
                    )),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
    );
  }
}

// ─── Menu Tab ───
class MenuTab extends StatelessWidget {
  final String workspaceSlug;
  final User? user;
  final VoidCallback onLogout;

  const MenuTab({super.key, required this.workspaceSlug, this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(workspaceSlug)),
      body: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Text(user!.displayName[0].toUpperCase(),
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user!.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(user!.email, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined, size: 20),
            title: const Text('Settings', style: TextStyle(fontSize: 14)),
            dense: true,
          ),
          ListTile(
            leading: Icon(Icons.logout, size: 20, color: Colors.red[400]),
            title: Text('Disconnect', style: TextStyle(fontSize: 14, color: Colors.red[400])),
            dense: true,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Disconnect'),
                  content: const Text('Disconnect from this instance?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
                  ],
                ),
              );
              if (ok == true) {
                await SecureStorage.clear();
                ApiClient.reset();
                onLogout();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Project Screen (tabs for individual project) ───
class ProjectScreen extends StatelessWidget {
  final String workspaceSlug;
  final Project project;

  const ProjectScreen({super.key, required this.workspaceSlug, required this.project});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Issues'),
              Tab(text: 'Pages'),
              Tab(text: 'Modules'),
              Tab(text: 'Cycles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            IssuesTabScreen(
                workspaceSlug: workspaceSlug,
                projectId: project.id,
                projectIdentifier: project.identifier),
            PageListScreen(workspaceSlug: workspaceSlug, projectId: project.id),
            ModuleListScreen(workspaceSlug: workspaceSlug, projectId: project.id),
            CycleListScreen(workspaceSlug: workspaceSlug, projectId: project.id),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Icon(
          isActive ? activeIcon : icon,
          size: 22,
          color: isActive
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }
}
