import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/favorite.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../../providers/favorites_provider.dart';
import '../project/project_screen.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/section_header.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../config/theme.dart';

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

  /// Set when the project read failed and there is nothing cached to fall back
  /// on. `_load` used to have no `catch` at all, so a throw left
  /// `_initialLoading` set and [ProjectListSkeleton] shimmered for ever.
  String? _error;

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

  /// Counted per project, filled in one at a time in the background. A project
  /// missing from this map has not been counted *yet*, which is a different
  /// thing from a project with nothing in it — see [_projectRow].
  final Map<String, int> _issueCounts = {};

  Future<void> _load() async {
    final cache = _cache;
    // The favourites read is one request for the whole workspace and every
    // list that draws a star shares it, so it is fired here rather than waited
    // on: the project rows render either way, they just start unstarred.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
    try {
      await cache.loadProjects(widget.workspaceSlug);
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          // Only when the cache had nothing either: a failed refresh over rows
          // already on screen keeps the rows.
          if (_allProjects.isEmpty) _error = 'Could not load projects';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _initialLoading = false;
        _error = null;
      });
    }
    // Load issue counts in background
    _loadIssueCounts();
  }

  Future<void> _loadIssueCounts() async {
    // Fired unawaited from _load once its own await has returned, so the tab
    // can already be disposed here — and `_cache` is a ref.read, which throws
    // on a disposed element.
    if (!mounted) return;
    final cache = _cache;
    final projects = cache.getProjects(widget.workspaceSlug) ?? [];
    for (final p in projects) {
      try {
        await cache.loadProjectCoreData(widget.workspaceSlug, p.id);
      } catch (_) {
        // One project that will not load must not stop the rest being
        // counted; its row keeps saying it does not know.
        continue;
      }
      final issues = cache.getIssues(widget.workspaceSlug, p.id) ?? [];
      _issueCounts[p.id] = issues.length;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    final cache = _cache;
    await Future.wait([
      cache.loadProjects(widget.workspaceSlug, force: true),
      ref
          .read(favoritesProvider.notifier)
          .load(widget.workspaceSlug, force: true),
    ]);
    if (mounted) setState(() {});
  }

  /// Everything the workspace has, before the search filter and before
  /// favourites are lifted to the front. This is the order the badge hues are
  /// assigned from, so that starring a project — or typing in the search box —
  /// does not recolour it.
  List<Project> get _allProjects =>
      _cache.getProjects(widget.workspaceSlug) ?? [];

  List<Project> get _projects {
    final all = _allProjects;
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.identifier.toLowerCase().contains(q))
        .toList();
  }

  Color _badgeColor(BuildContext context, int index) =>
      PlaneTheme.projectBadgeColor(context, index);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Plane orders its cycle, module, view and page lists `-is_favorite` on the
    // server. It does not do it for projects: `ProjectViewSet.list` builds its
    // own `.values(...)` projection and drops the annotation the queryset
    // carries. Doing it here is what makes the five lists agree.
    final projects = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.project, _projects, (p) => p.id);
    // Hue is assigned from the unsorted, unfiltered order, so a project keeps
    // its badge colour when it is starred or searched for.
    final hueOf = {
      for (final (index, p) in _allProjects.indexed) p.id: index,
    };

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
                    child: _error != null && projects.isEmpty
                        ? ScrollableCenter(
                            padding: const EdgeInsets.only(bottom: 100),
                            child: ErrorStateWidget(
                                message: _error, onRetry: _load),
                          )
                        : projects.isEmpty
                            ? ScrollableEmptyState(
                                message: _searchQuery.isEmpty
                                    ? 'No projects yet'
                                    : 'No projects match "$_searchQuery"',
                                icon: Icons.grid_view_outlined,
                                subtitle: _searchQuery.isEmpty
                                    ? 'Projects are created in the web app'
                                    : null,
                                padding: const EdgeInsets.only(bottom: 100),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.only(bottom: 100, top: 4),
                                itemCount: projects.length,
                                itemBuilder: (ctx, i) => _projectRow(
                                  projects[i],
                                  hueOf[projects[i].id] ?? i,
                                ),
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  /// A project is a row like any other.
  ///
  /// This used to be a hand-rolled card — its own surface, its own padding, its
  /// own chevron — which is exactly the divergence [PlaneRow] exists to stop.
  /// It also had nowhere to put a per-row control: the whole card was one
  /// gesture target, so a star inside it would have been swallowed. The
  /// identifier badge survives as the `leading` slot, and the star goes in
  /// `trailing`, the one slot outside the row's own semantics node.
  Widget _projectRow(Project project, int hue) {
    final theme = Theme.of(context);
    final badge = _badgeColor(context, hue);
    // Counting happens project by project after the list is already on screen,
    // and `?? 0` rendered "0 active issues" as a fact for every project that
    // had not been reached yet. A project with nothing in it and a project we
    // have not looked at are different answers.
    final count = _issueCounts[project.id];
    final issues =
        count == null ? 'Counting active issues…' : '$count active issues';

    return PlaneRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: badge.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(M3EShape.medium),
        ),
        child: Center(
          child: Text(
            project.identifier,
            style: M3EType.emphasized(theme.textTheme.titleSmall!)
                .copyWith(color: badge),
          ),
        ),
      ),
      title: project.name,
      subtitle: issues,
      semanticLabel: '${project.name}, ${project.identifier}, $issues',
      trailing: FavoriteToggle(
        workspaceSlug: widget.workspaceSlug,
        entity: FavoriteEntity.project,
        entityId: project.id,
        entityName: project.name,
        // A project favourite is scoped to itself. That is what Plane's own
        // per-entity endpoint writes, and the workspace list only returns
        // project-scoped rows whose project the caller is still a member of.
        projectId: project.id,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectScreen(
            workspaceSlug: widget.workspaceSlug,
            project: project,
          ),
        ),
      ),
    );
  }
}
