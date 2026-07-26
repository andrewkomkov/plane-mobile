import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/cycle.dart';
import '../../models/favorite.dart';
import '../../models/project.dart';
import '../../models/workspace_rollup.dart';
import '../../providers/favorites_provider.dart';
import '../../services/project_service.dart';
import '../../services/workspace_rollup_service.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/plane_row.dart';
import '../cycles/cycle_detail_screen.dart';
import 'project_grouped_list.dart';

/// Every live cycle in the workspace, under a heading per project.
///
/// The project-level cycle list groups by status, because inside one project a
/// cycle's status is the thing that separates it from the next. Across projects
/// it is not: what a reader needs first is whose sprint this is. Status stays
/// on the row, as the colour of the icon and the progress bar.
class WorkspaceCyclesScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;

  const WorkspaceCyclesScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<WorkspaceCyclesScreen> createState() =>
      _WorkspaceCyclesScreenState();
}

class _WorkspaceCyclesScreenState extends ConsumerState<WorkspaceCyclesScreen> {
  List<ProjectScoped<Cycle>> _cycles = [];
  Map<String, Project> _projects = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // One request for the whole workspace, shared by every list that draws a
    // star. Fired rather than awaited: the rows render either way, they just
    // start unstarred.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
    try {
      final results = await Future.wait([
        WorkspaceRollupService.getCycles(widget.workspaceSlug),
        ProjectService.getProjects(widget.workspaceSlug),
      ]);
      if (!mounted) return;
      final projects = results[1] as List<Project>;
      setState(() {
        _cycles = results[0] as List<ProjectScoped<Cycle>>;
        _projects = {for (final p in projects) p.id: p};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Counted after grouping, not before: the rollup includes projects the
  /// caller is not in, and a header that counted those would not match the
  /// rows underneath it.
  int get _visibleCount => ProjectGroupedList.group<Cycle>(_cycles, _projects)
      .fold<int>(0, (sum, g) => sum + g.value.length);

  @override
  Widget build(BuildContext context) {
    final count = _visibleCount;
    // The project-level cycle list lifts its starred cycles to the front and
    // this one did not, so the same cycle sat in a different place depending on
    // which list you opened it from. Ordering the flat list before it is
    // grouped keeps the lift inside each project's run of rows.
    final ordered = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.cycle, _cycles, (e) => e.item.id);
    return Scaffold(
      appBar: M3EAppBar(
        title: 'All cycles',
        // The same sentence the project lists put in a body header, so the two
        // renderings of one count at least agree on the words.
        subtitle: _loading ? null : ListCountHeader.label(count, 'cycle'),
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load cycles', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ProjectGroupedList<Cycle>(
                    items: ordered,
                    projects: _projects,
                    emptyState: const EmptyStateWidget(
                      message: 'No cycles in this workspace',
                      icon: Icons.loop,
                      subtitle:
                          'Cycles from every project you belong to appear here',
                    ),
                    rowBuilder: _cycleRow,
                  ),
                ),
    );
  }

  Widget _cycleRow(BuildContext context, Project project, Cycle cycle) {
    final status = cycle.computedStatus;
    final statusColor = _statusColor(status);
    final dates =
        [cycle.startDate, cycle.endDate].where((d) => d != null).join(' - ');
    final count = '${cycle.completedIssues}/${cycle.totalIssues}';

    return PlaneRow(
      icon: Icons.loop,
      iconColor: statusColor,
      // The heading above names the project for a run of rows; the identifier
      // line names it again per row, so a row read on its own — by a screen
      // reader, or by `adb shell uiautomator`, neither of which sees the
      // heading as part of the row — is still attributable.
      identifier: project.identifier,
      title: cycle.name,
      subtitle: dates.isEmpty ? null : dates,
      subtitleTrailing: count,
      progress: cycle.progress,
      progressColor: statusColor,
      semanticLabel: [
        cycle.name,
        'in ${project.name}',
        _statusLabel(status),
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      // The four project-level lists all carry the star and the three workspace
      // rollups did not, so a cycle could be starred from one list and not from
      // the other. `trailing` is the only slot outside the row's own semantics
      // node, which is what lets the star keep a name of its own.
      trailing: FavoriteToggle(
        workspaceSlug: widget.workspaceSlug,
        entity: FavoriteEntity.cycle,
        entityId: cycle.id,
        entityName: cycle.name,
        projectId: project.id,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CycleDetailScreen(
            workspaceSlug: widget.workspaceSlug,
            projectId: project.id,
            cycle: cycle,
          ),
        ),
      ),
    );
  }

  // Matching the project-level cycle list, so the same cycle keeps the same
  // colour in both places.
  Color _statusColor(String status) {
    switch (status) {
      case 'current':
        return PlaneTheme.started;
      case 'upcoming':
        return PlaneTheme.low;
      case 'completed':
        return PlaneTheme.completed;
      default:
        return PlaneTheme.backlog;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'current':
        return 'Active';
      case 'upcoming':
        return 'Upcoming';
      case 'completed':
        return 'Completed';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }
}
