import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/favorite.dart';
import '../../models/module.dart';
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
import '../../widgets/property_chip.dart';
import '../modules/module_detail_screen.dart';
import 'project_grouped_list.dart';

/// Every live module in the workspace, under a heading per project.
///
/// Same shape as the cycle rollup and for the same reason: a module named
/// "Payments" says nothing until you know whose Payments it is.
class WorkspaceModulesScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;

  const WorkspaceModulesScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<WorkspaceModulesScreen> createState() =>
      _WorkspaceModulesScreenState();
}

class _WorkspaceModulesScreenState
    extends ConsumerState<WorkspaceModulesScreen> {
  List<ProjectScoped<Module>> _modules = [];
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
    // Fired rather than awaited, like the cycle rollup: the rows render either
    // way, they just start unstarred.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
    try {
      final results = await Future.wait([
        WorkspaceRollupService.getModules(widget.workspaceSlug),
        ProjectService.getProjects(widget.workspaceSlug),
      ]);
      if (!mounted) return;
      final projects = results[1] as List<Project>;
      setState(() {
        _modules = results[0] as List<ProjectScoped<Module>>;
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

  /// Counted after grouping — the rollup carries projects the caller is not in.
  int get _visibleCount => ProjectGroupedList.group<Module>(_modules, _projects)
      .fold<int>(0, (sum, g) => sum + g.value.length);

  @override
  Widget build(BuildContext context) {
    final count = _visibleCount;
    // Starred modules to the front, matching the project-level module list.
    final ordered = ref
        .watch(favoritesProvider)
        .favoritesFirst(FavoriteEntity.module, _modules, (e) => e.item.id);
    return Scaffold(
      appBar: M3EAppBar(
        title: 'All modules',
        subtitle: _loading ? null : ListCountHeader.label(count, 'module'),
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load modules', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ProjectGroupedList<Module>(
                    items: ordered,
                    projects: _projects,
                    emptyState: const EmptyStateWidget(
                      message: 'No modules in this workspace',
                      icon: Icons.view_module,
                      subtitle:
                          'Modules from every project you belong to appear here',
                    ),
                    rowBuilder: _moduleRow,
                  ),
                ),
    );
  }

  Widget _moduleRow(BuildContext context, Project project, Module module) {
    final statusColor = _statusColor(module.status);
    final statusLabel = _statusLabel(module.status);
    final dates = [module.startDate, module.targetDate]
        .where((d) => d != null)
        .join(' - ');
    final count = '${module.completedIssues}/${module.totalIssues}';

    return PlaneRow(
      icon: Icons.view_module,
      iconColor: statusColor,
      // Named per row as well as per heading: a heading is not part of the
      // row's semantics node, so automation and screen readers only ever get
      // what the row itself says.
      identifier: project.identifier,
      title: module.name,
      subtitle: dates.isEmpty ? null : dates,
      subtitleTrailing: count,
      progress: module.progress,
      progressColor: statusColor,
      metadata: [
        PropertyChip(
          icon: Icons.circle,
          iconColor: statusColor,
          label: statusLabel,
        ),
      ],
      semanticLabel: [
        module.name,
        'in ${project.name}',
        statusLabel,
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      // Present on the project-level module list and missing here, so the same
      // module could be starred from one and not the other.
      trailing: FavoriteToggle(
        workspaceSlug: widget.workspaceSlug,
        entity: FavoriteEntity.module,
        entityId: module.id,
        entityName: module.name,
        projectId: project.id,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ModuleDetailScreen(
            workspaceSlug: widget.workspaceSlug,
            projectId: project.id,
            module: module,
          ),
        ),
      ),
    );
  }

  // Matching the project-level module list so a module keeps its colour and
  // its wording wherever it is shown.
  Color _statusColor(String? status) {
    switch (status) {
      case 'planned':
        return PlaneTheme.low;
      case 'in-progress':
        return PlaneTheme.started;
      case 'paused':
        return PlaneTheme.medium;
      case 'completed':
        return PlaneTheme.completed;
      case 'cancelled':
        return PlaneTheme.cancelled;
      default:
        return PlaneTheme.backlog;
    }
  }

  String _statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Backlog';
    return status
        .split('-')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
