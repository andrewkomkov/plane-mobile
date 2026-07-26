import 'package:flutter/material.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/module_service.dart';
import '../../providers/data_providers.dart';
import '../../models/module.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/property_chip.dart';
import 'module_detail_screen.dart';

class ModuleListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const ModuleListScreen(
      {super.key, required this.workspaceSlug, required this.projectId});

  @override
  ConsumerState<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends ConsumerState<ModuleListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _initialLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Module> get _modules =>
      _cache.getModules(widget.workspaceSlug, widget.projectId) ?? [];

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await _cache.loadModules(widget.workspaceSlug, widget.projectId,
          force: true);
      if (mounted) setState(() => _initialLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initialLoading = false;
        });
      }
    }
  }

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

  void _showCreateModuleDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedStatus = 'planned';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New module'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3ETextField(
                  label: 'Name',
                  controller: nameController,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                M3ETextField(
                  label: 'Description',
                  controller: descController,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: moduleStatusFieldDecoration(ctx),
                  items: [
                    'backlog',
                    'planned',
                    'in-progress',
                    'paused',
                    'completed',
                    'cancelled',
                  ]
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(_statusLabel(s))))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedStatus = v ?? 'planned'),
                  isExpanded: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ModuleService.createModule(
                    widget.workspaceSlug,
                    widget.projectId,
                    {
                      'name': name,
                      if (descController.text.trim().isNotEmpty)
                        'description': descController.text.trim(),
                      'status': selectedStatus,
                    },
                  );
                  _cache.invalidateModules(
                      widget.workspaceSlug, widget.projectId);
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create module: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoading && _modules.isEmpty) {
      return const ProjectListSkeleton();
    }
    if (_error != null && _modules.isEmpty) {
      return ErrorStateWidget(
          message: 'Failed to load modules', onRetry: _load);
    }
    if (_modules.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          message: 'No modules',
          icon: Icons.view_module,
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _modules.length,
          itemBuilder: (ctx, i) {
            final m = _modules[i];
            return _moduleRow(
              module: m,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModuleDetailScreen(
                      workspaceSlug: widget.workspaceSlug,
                      projectId: widget.projectId,
                      module: m,
                    ),
                  ),
                );
                _cache.invalidateModules(
                    widget.workspaceSlug, widget.projectId);
                _load();
              },
            );
          },
        ),
      ),
    );
  }

  /// Same row as a cycle, with the status carried by a chip because this list
  /// is flat where the cycle list groups by status.
  Widget _moduleRow({required Module module, required VoidCallback onTap}) {
    final statusColor = _statusColor(module.status);
    final statusLabel = _statusLabel(module.status);
    final dates = [module.startDate, module.targetDate]
        .where((d) => d != null)
        .join(' - ');
    final count = '${module.completedIssues}/${module.totalIssues}';

    return PlaneRow(
      icon: Icons.view_module,
      iconColor: statusColor,
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
        statusLabel,
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      onTap: onTap,
    );
  }
}
