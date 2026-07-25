import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../project/project_screen.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/motion.dart';

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

    return M3EFlexibleHeaderScaffold(
      title: 'Projects',
      actions: [
        IconButton(
          tooltip: 'How to create a project',
          icon: Icon(Icons.help_outline,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Create projects in the web app')),
            );
          },
        ),
      ],
      // Search stays pinned under the title: it filters the whole list, so
      // scrolling it away would strand the user in filtered results.
      bottom: Semantics(
        label: 'Search projects',
        textField: true,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(M3EShape.full),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                size: 19, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                    fontSize: 15, color: theme.colorScheme.onSurface),
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
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              label: 'Active projects',
              count: projects.length,
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
                            child: M3EPressable(
                              pressedScale: 0.975,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectScreen(
                                      workspaceSlug: widget.workspaceSlug,
                                      project: p),
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius:
                                      BorderRadius.circular(M3EShape.large),
                                ),
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
                                          borderRadius: BorderRadius.circular(M3EShape.medium),
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
