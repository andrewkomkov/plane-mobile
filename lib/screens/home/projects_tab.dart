import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../project/project_screen.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/screen_header.dart';

class ProjectsTab extends ConsumerStatefulWidget {
  final String workspaceSlug;
  const ProjectsTab({super.key, required this.workspaceSlug});

  @override
  ConsumerState<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends ConsumerState<ProjectsTab>
    with AutomaticKeepAliveClientMixin {
  bool _initialLoading = true;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProjectsTab old) {
    super.didUpdateWidget(old);
    if (old.workspaceSlug != widget.workspaceSlug) _load();
  }

  Map<String, int> _issueCounts = {};

  Future<void> _load() async {
    final cache = _cache;
    await cache.loadProjects(widget.workspaceSlug);
    if (mounted) setState(() => _initialLoading = false);
    // Load issue counts in background
    _loadIssueCounts();
  }

  Future<void> _loadIssueCounts() async {
    final cache = _cache;
    final projects = cache.getProjects(widget.workspaceSlug) ?? [];
    for (final p in projects) {
      await cache.loadProjectCoreData(widget.workspaceSlug, p.id);
      final issues = cache.getIssues(widget.workspaceSlug, p.id) ?? [];
      _issueCounts[p.id] = issues.length;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    final cache = _cache;
    await cache.loadProjects(widget.workspaceSlug, force: true);
    if (mounted) setState(() {});
  }

  List<Project> get _projects {
    final all = _cache.getProjects(widget.workspaceSlug) ?? [];
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.identifier.toLowerCase().contains(q))
        .toList();
  }

  // Compute a bg color for the identifier badge based on index
  static const _badgeColors = [
    Color(0xFF5E6AD2), // primary indigo
    Color(0xFFA56500), // tertiary
    Color(0xFF42466E), // secondary
    Color(0xFF93000A), // error
    Color(0xFF454652), // outline variant
    Color(0xFF22C55E), // green
  ];

  Color _badgeColor(int index) =>
      _badgeColors[index % _badgeColors.length];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final projects = _projects;

    return SafeArea(
      bottom: false,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Projects',
              actions: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit_square, size: 18, color: Colors.white),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create projects in the web app')),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.30),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search projects...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Row(
                children: [
                  Text(
                    'ACTIVE PROJECTS',
                    style: TextStyle(
                      fontSize: PlaneTheme.fontSection,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${projects.length} Total',
                    style: TextStyle(
                      fontSize: PlaneTheme.fontSmall,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _initialLoading && projects.isEmpty
                  ? const ProjectListSkeleton()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100, top: 4),
                        itemCount: projects.length,
                        itemBuilder: (ctx, i) {
                          final p = projects[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 3),
                            child: Material(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProjectScreen(
                                        workspaceSlug: widget.workspaceSlug,
                                        project: p),
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Identifier badge
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _badgeColor(i).withValues(alpha: 0.20),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            p.identifier,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _badgeColor(i),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Project name + active issues
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: PlaneTheme.fontBody,
                                                fontWeight: PlaneTheme.fontBodyWeight,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_issueCounts[p.id] ?? 0} active issues',
                                              style: TextStyle(
                                                fontSize: PlaneTheme.fontCaption,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          size: 20, color: theme.colorScheme.outline),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
    );
  }
}
