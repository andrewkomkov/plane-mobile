import 'package:flutter/material.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/cycle_service.dart';
import '../../providers/data_providers.dart';
import '../../models/cycle.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/section_header.dart';
import 'cycle_detail_screen.dart';

class CycleListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const CycleListScreen(
      {super.key, required this.workspaceSlug, required this.projectId});

  @override
  ConsumerState<CycleListScreen> createState() => _CycleListScreenState();
}

class _CycleListScreenState extends ConsumerState<CycleListScreen>
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

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await _cache.loadCycles(widget.workspaceSlug, widget.projectId,
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

  List<Cycle> get _cycles =>
      _cache.getCycles(widget.workspaceSlug, widget.projectId) ?? [];

  Map<String, List<Cycle>> get _groupedCycles {
    final groups = <String, List<Cycle>>{
      'current': [],
      'upcoming': [],
      'completed': [],
      'draft': [],
    };
    for (final c in _cycles) {
      final status = c.computedStatus;
      groups.putIfAbsent(status, () => []);
      groups[status]!.add(c);
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'current':
        return PlaneTheme.started;
      case 'upcoming':
        return PlaneTheme.low;
      case 'completed':
        return PlaneTheme.completed;
      case 'draft':
        return PlaneTheme.backlog;
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
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  void _showCreateCycleDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New cycle'),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        child: Text(
                          startDate != null
                              ? _formatDate(startDate!)
                              : 'Start date',
                          style: M3EType.emphasized(
                              Theme.of(ctx).textTheme.labelMedium!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                        child: Text(
                          endDate != null ? _formatDate(endDate!) : 'End date',
                          style: M3EType.emphasized(
                              Theme.of(ctx).textTheme.labelMedium!),
                        ),
                      ),
                    ),
                  ],
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
                  await CycleService.createCycle(
                    widget.workspaceSlug,
                    widget.projectId,
                    {
                      'name': name,
                      if (descController.text.trim().isNotEmpty)
                        'description': descController.text.trim(),
                      if (startDate != null)
                        'start_date': _formatDate(startDate!),
                      if (endDate != null) 'end_date': _formatDate(endDate!),
                    },
                  );
                  _cache.invalidateCycles(
                      widget.workspaceSlug, widget.projectId);
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create cycle: $e')),
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

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoading && _cycles.isEmpty) {
      return const ProjectListSkeleton();
    }
    if (_error != null && _cycles.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load cycles', onRetry: _load);
    }
    if (_cycles.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          message: 'No cycles',
          icon: Icons.loop,
        ),
      );
    }

    final grouped = _groupedCycles;
    final entries = grouped.entries.toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
          itemBuilder: (ctx, index) {
            int current = 0;
            for (final entry in entries) {
              if (index == current) {
                return SectionHeader(
                  label: _statusLabel(entry.key),
                  count: entry.value.length,
                  color: _statusColor(entry.key),
                );
              }
              current++;
              final cycleIndex = index - current;
              if (cycleIndex < entry.value.length) {
                final cycle = entry.value[cycleIndex];
                return _cycleRow(
                  cycle: cycle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CycleDetailScreen(
                          workspaceSlug: widget.workspaceSlug,
                          projectId: widget.projectId,
                          cycle: cycle,
                        ),
                      ),
                    );
                    _cache.invalidateCycles(
                        widget.workspaceSlug, widget.projectId);
                    _load();
                  },
                );
              }
              current += entry.value.length;
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// A cycle is a row like any other: the progress bar and the completed count
  /// are slots, not a reason for this screen to draw its own card.
  Widget _cycleRow({required Cycle cycle, required VoidCallback onTap}) {
    final statusColor = _statusColor(cycle.computedStatus);
    final dates =
        [cycle.startDate, cycle.endDate].where((d) => d != null).join(' - ');
    final count = '${cycle.completedIssues}/${cycle.totalIssues}';

    return PlaneRow(
      icon: Icons.loop,
      iconColor: statusColor,
      title: cycle.name,
      subtitle: dates.isEmpty ? null : dates,
      subtitleTrailing: count,
      progress: cycle.progress,
      progressColor: statusColor,
      semanticLabel: [
        cycle.name,
        _statusLabel(cycle.computedStatus),
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      onTap: onTap,
    );
  }
}
