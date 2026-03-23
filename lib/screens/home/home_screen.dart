import 'package:flutter/material.dart';
import '../../config/secure_storage.dart';
import '../../config/api_client.dart';
import '../../services/project_service.dart';
import '../../services/auth_service.dart';
import '../../models/project.dart';
import '../../models/user.dart';
import '../issues/issue_list_screen.dart';
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
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  String _workspaceSlug = '';
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _workspaceSlug = await SecureStorage.getWorkspaceSlug() ?? '';
      final results = await Future.wait([
        ProjectService.getProjects(_workspaceSlug),
        AuthService.getCurrentUser(),
      ]);
      setState(() {
        _projects = results[0] as List<Project>;
        _user = results[1] as User;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed == true) {
      await SecureStorage.clear();
      ApiClient.reset();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_workspaceSlug.isNotEmpty ? _workspaceSlug : 'Projects',
                style: const TextStyle(fontSize: 18)),
            if (_user != null)
              Text(_user!.displayName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(workspaceSlug: _workspaceSlug),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadProjects, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: _projects.isEmpty
                      ? const Center(child: Text('No projects'))
                      : ListView.builder(
                          itemCount: _projects.length,
                          itemBuilder: (ctx, i) => _ProjectCard(
                            project: _projects[i],
                            workspaceSlug: _workspaceSlug,
                          ),
                        ),
                ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final String workspaceSlug;

  const _ProjectCard({required this.project, required this.workspaceSlug});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectScreen(
              workspaceSlug: workspaceSlug,
              project: project,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(project.identifier,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onPrimaryContainer)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (project.description != null && project.description!.isNotEmpty)
                      Text(project.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Text('${project.totalMembers}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              Icon(Icons.people_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

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
              Tab(icon: Icon(Icons.task_alt, size: 18), text: 'Issues'),
              Tab(icon: Icon(Icons.description, size: 18), text: 'Pages'),
              Tab(icon: Icon(Icons.view_module, size: 18), text: 'Modules'),
              Tab(icon: Icon(Icons.loop, size: 18), text: 'Cycles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            IssueListScreen(
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
