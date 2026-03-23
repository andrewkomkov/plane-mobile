import 'package:flutter/material.dart';
import '../../config/secure_storage.dart';
import '../../config/api_client.dart';
import '../../services/project_service.dart';
import '../../models/project.dart';
import '../issues/issue_list_screen.dart';
import '../pages/page_list_screen.dart';

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
      final projects = await ProjectService.getProjects(_workspaceSlug);
      setState(() {
        _projects = projects;
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
    await SecureStorage.clear();
    ApiClient.reset();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workspaceSlug.isNotEmpty ? _workspaceSlug : 'Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadProjects,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openProject(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    project.identifier,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    if (project.description != null &&
                        project.description!.isNotEmpty)
                      Text(project.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _openProject(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProjectTabScreen(
          workspaceSlug: workspaceSlug,
          project: project,
        ),
      ),
    );
  }
}

class _ProjectTabScreen extends StatelessWidget {
  final String workspaceSlug;
  final Project project;

  const _ProjectTabScreen({
    required this.workspaceSlug,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Issues'),
              Tab(text: 'Pages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            IssueListScreen(
              workspaceSlug: workspaceSlug,
              projectId: project.id,
              projectIdentifier: project.identifier,
            ),
            PageListScreen(
              workspaceSlug: workspaceSlug,
              projectId: project.id,
            ),
          ],
        ),
      ),
    );
  }
}
