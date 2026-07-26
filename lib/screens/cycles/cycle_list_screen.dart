import 'package:flutter/material.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/cycle_service.dart';
import '../../providers/data_providers.dart';
import '../../models/cycle.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
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

  /// Whether the list is showing the archive instead of the live cycles.
  bool _showArchived = false;

  /// Archived cycles are held here rather than in [DataCache].
  ///
  /// The cache is backed by SQLite and shared with the offline path, and an
  /// archive is neither what the rest of the app reads from it nor something
  /// worth persisting — it is a view a user opens occasionally and expects to
  /// be current.
  List<Cycle>? _archived;
  bool _archivedLoading = false;

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
    if (_showArchived) return _loadArchived();
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

  Future<void> _loadArchived() async {
    setState(() {
      _archivedLoading = true;
      _error = null;
    });
    try {
      final archived = await CycleService.getArchivedCycles(
          widget.workspaceSlug, widget.projectId);
      if (mounted) {
        setState(() {
          _archived = archived;
          _archivedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _archivedLoading = false;
        });
      }
    }
  }

  void _toggleArchived(bool value) {
    setState(() {
      _showArchived = value;
      _error = null;
    });
    // Either direction refetches. Going in, a cycle archived from the detail
    // screen a moment ago has to be here; coming back out, the live cache was
    // invalidated by the restore that happened while we were in, so the live
    // list would otherwise render empty.
    if (value) {
      _loadArchived();
    } else {
      _load();
    }
  }

  Future<void> _unarchive(Cycle cycle) async {
    try {
      await CycleService.unarchiveCycle(
          widget.workspaceSlug, widget.projectId, cycle.id);
      // The live list gained a cycle it has never seen, so it cannot be
      // trusted until it is refetched.
      _cache.invalidateCycles(widget.workspaceSlug, widget.projectId);
      await _loadArchived();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cycle.name} restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore cycle: $e')),
        );
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

    if (!_showArchived && _initialLoading && _cycles.isEmpty) {
      return const ProjectListSkeleton();
    }

    return Scaffold(
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _showArchived ? _archivedList() : _liveList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Count plus the archive toggle, matching the header the work-item list
  /// already carries so the two lists do not each invent their own chrome.
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final count = _showArchived ? (_archived?.length ?? 0) : _cycles.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Text('$count ${count == 1 ? 'cycle' : 'cycles'}',
              style: theme.textTheme.bodySmall),
          const Spacer(),
          ArchiveToggle(
            showArchived: _showArchived,
            entityPlural: 'cycles',
            onChanged: _toggleArchived,
          ),
        ],
      ),
    );
  }

  Widget _liveList() {
    if (_error != null && _cycles.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load cycles', onRetry: _load);
    }
    if (_cycles.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: EmptyStateWidget(message: 'No cycles', icon: Icons.loop),
        ),
      ]);
    }

    final entries = _groupedCycles.entries.toList();
    return ListView.builder(
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
            return _cycleRow(cycle: entry.value[cycleIndex]);
          }
          current += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _archivedList() {
    if (_error != null) {
      return ErrorStateWidget(
          message: 'Failed to load archived cycles', onRetry: _loadArchived);
    }
    final archived = _archived;
    if (archived == null || (_archivedLoading && archived.isEmpty)) {
      return const ProjectListSkeleton();
    }
    if (archived.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: EmptyStateWidget(
            message: 'No archived cycles',
            icon: Icons.inventory_2_outlined,
            subtitle: 'Cycles archived from here or from the web appear here',
          ),
        ),
      ]);
    }
    return ListView.builder(
      itemCount: archived.length,
      itemBuilder: (ctx, i) => _cycleRow(cycle: archived[i]),
    );
  }

  /// A cycle is a row like any other: the progress bar and the completed count
  /// are slots, not a reason for this screen to draw its own card.
  ///
  /// Archived is the same row with different slot contents — a muted icon, the
  /// archive date where the date range would be, and a restore button in the
  /// trailing slot, which is the one part of a row that keeps its own
  /// semantics node and so stays reachable from automation.
  Widget _cycleRow({required Cycle cycle}) {
    final theme = Theme.of(context);
    final archived = cycle.isArchived;
    final statusColor = archived
        ? theme.colorScheme.onSurfaceVariant
        : _statusColor(cycle.computedStatus);
    final dates =
        [cycle.startDate, cycle.endDate].where((d) => d != null).join(' - ');
    final count = '${cycle.completedIssues}/${cycle.totalIssues}';

    return PlaneRow(
      icon: archived ? Icons.inventory_2_outlined : Icons.loop,
      iconColor: statusColor,
      title: cycle.name,
      // The archive date takes the slot the date range holds on a live cycle:
      // once a cycle is put away, when that happened is the thing worth
      // reading, and the range is still in the label.
      subtitle: archived
          ? archivedOnLabel(cycle.archivedAt)
          : (dates.isEmpty ? null : dates),
      subtitleTrailing: count,
      progress: cycle.progress,
      progressColor: statusColor,
      semanticLabel: [
        cycle.name,
        if (archived) archivedOnLabel(cycle.archivedAt),
        if (!archived) _statusLabel(cycle.computedStatus),
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      trailing: archived
          ? M3EIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Restore cycle ${cycle.name}',
              size: M3EIconButtonSize.small,
              onPressed: () => _confirmUnarchive(cycle),
            )
          : null,
      onTap: () => _openCycle(cycle),
    );
  }

  Future<void> _openCycle(Cycle cycle) async {
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
    if (!mounted) return;
    _cache.invalidateCycles(widget.workspaceSlug, widget.projectId);
    _load();
  }

  /// Restoring puts a cycle back into everyone's list, so it is confirmed even
  /// though nothing is destroyed by it.
  Future<void> _confirmUnarchive(Cycle cycle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore cycle'),
        content: Text('Move "${cycle.name}" back into the active cycles?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true) await _unarchive(cycle);
  }
}
