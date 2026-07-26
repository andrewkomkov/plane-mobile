import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/cycle.dart';
import '../../models/project.dart';
import '../../models/workspace_rollup.dart';
import '../../services/project_service.dart';
import '../../services/workspace_rollup_service.dart';
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
    return Scaffold(
      appBar: M3EAppBar(
        title: 'All cycles',
        subtitle: _loading ? null : '$count ${count == 1 ? 'cycle' : 'cycles'}',
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load cycles', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ProjectGroupedList<Cycle>(
                    items: _cycles,
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
