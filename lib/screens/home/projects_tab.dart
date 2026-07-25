import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../project/project_screen.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/section_header.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/typography.dart';

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
        M3EIconButton(
          icon: Icons.help_outline,
          tooltip: 'How to create a project',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Create projects in the web app')),
            );
          },
        ),
      ],
      // Search stays pinned under the title: it filters the whole list, so
      // scrolling it away would strand the user in filtered results.
      bottom: M3ETextField(
        label: 'Search projects',
        hint: 'Search projects...',
        compact: true,
        prefixIcon: Icons.search,
        onChanged: (v) => setState(() => _searchQuery = v),
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
                                            style: M3EType.emphasized(
                                                    theme.textTheme.titleSmall!)
                                                .copyWith(
                                                    color: _badgeColor(i)),
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
                                              style: theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_issueCounts[p.id] ?? 0} active issues',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          size: 20,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
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
