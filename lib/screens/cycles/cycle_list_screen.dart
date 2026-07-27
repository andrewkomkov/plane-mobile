import 'package:flutter/material.dart';
import '../../utils/say.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/cycle_service.dart';
import '../../providers/data_providers.dart';
import '../../models/cycle.dart';
import '../../models/favorite.dart';
import '../../providers/favorites_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/section_header.dart';
import 'cycle_detail_screen.dart';

class CycleListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// Whether the signed-in user may create a cycle here. Resolved by
  /// `ProjectScreen` against the caller's project role; false until it lands,
  /// so the control never appears for someone the server would refuse.
  final bool canCreate;

  const CycleListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.canCreate = false,
  });

  @override
  ConsumerState<CycleListScreen> createState() => CycleListScreenState();
}

/// Public so that `ProjectScreen`'s primary app-bar action can start the create
/// flow through a [GlobalKey]. The flow stays here, with the list that has to
/// refresh after it and with the empty state that offers the same thing.
class CycleListScreenState extends ConsumerState<CycleListScreen>
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
    // One read per workspace, shared with every other list that draws a star.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
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
        say(context, '${cycle.name} restored');
      }
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not restore the cycle'));
      }
    }
  }

  List<Cycle> get _cycles =>
      _cache.getCycles(widget.workspaceSlug, widget.projectId) ?? [];

  /// Cycles by status, favourites first inside each status.
  ///
  /// Not a section of their own: a favourite cycle is still a current or a
  /// completed one, and lifting it out of its status group would cost the
  /// grouping that makes this list readable to save a user one glance.
  Map<String, List<Cycle>> _groupedCycles(FavoritesState favorites) {
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
    return groups.map((status, cycles) => MapEntry(
          status,
          favorites.favoritesFirst(FavoriteEntity.cycle, cycles, (c) => c.id),
        ));
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

  /// Opens the "new cycle" form.
  ///
  /// The one entry point, called from the project screen's primary action and
  /// from the empty state below. Does nothing when the caller's role would be
  /// refused — the controls are already hidden in that case, and this is the
  /// second lock on the same door.
  void startCreate() {
    if (!widget.canCreate) return;
    _showCreateCycleDialog();
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
                    sayError(
                        context,
                        describeApiError(e,
                            fallback: 'Could not create the cycle'));
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

    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _showArchived
                  ? _archivedList(favorites)
                  : _liveList(favorites),
            ),
          ),
        ],
      ),
    );
  }

  /// Count plus the archive toggle, matching the header the work-item list
  /// already carries so the two lists do not each invent their own chrome.
  Widget _header(BuildContext context) {
    final count = _showArchived ? (_archived?.length ?? 0) : _cycles.length;
    return ListCountHeader(
      count: count,
      singular: 'cycle',
      trailing: ArchiveToggle(
        showArchived: _showArchived,
        entityPlural: 'cycles',
        onChanged: _toggleArchived,
      ),
    );
  }

  Widget _liveList(FavoritesState favorites) {
    if (_error != null && _cycles.isEmpty) {
      return ErrorStateWidget(message: 'Failed to load cycles', onRetry: _load);
    }
    if (_cycles.isEmpty) {
      return ScrollableEmptyState(
        padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
        message: 'No cycles',
        icon: Icons.loop,
        subtitle: 'A cycle is a time box the team works an iteration in',
        action: widget.canCreate
            ? FilledButton.tonalIcon(
                onPressed: startCreate,
                icon: const Icon(Icons.add),
                label: const Text('New cycle'),
              )
            : null,
      );
    }

    final entries = _groupedCycles(favorites).entries.toList();
    return ListView.builder(
      // Without this a list too short to scroll cannot be pulled, so the
      // RefreshIndicator wrapping it never fires.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
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

  Widget _archivedList(FavoritesState favorites) {
    if (_error != null) {
      return ErrorStateWidget(
          message: 'Failed to load archived cycles', onRetry: _loadArchived);
    }
    final archived = _archived;
    if (archived == null || (_archivedLoading && archived.isEmpty)) {
      return const ProjectListSkeleton();
    }
    if (archived.isEmpty) {
      return ScrollableEmptyState(
        padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
        message: 'No archived cycles',
        icon: Icons.inventory_2_outlined,
        subtitle: 'Cycles archived from here or from the web appear here',
      );
    }
    final ordered =
        favorites.favoritesFirst(FavoriteEntity.cycle, archived, (c) => c.id);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: appNavBarClearance(context)),
      itemCount: ordered.length,
      itemBuilder: (ctx, i) => _cycleRow(cycle: ordered[i]),
    );
  }

  /// A cycle is a row like any other: the progress bar and the completed count
  /// are slots, not a reason for this screen to draw its own card.
  ///
  /// Archived is the same row with different slot contents — a muted icon, the
  /// archive date where the date range would be, and a restore button in the
  /// trailing slot, which is the one part of a row that keeps its own
  /// semantics node and so stays reachable from automation. The favourite star
  /// shares that slot for the same reason, and is offered on archived cycles
  /// too: a cycle starred before it was put away has nowhere else to be
  /// unstarred from.
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteToggle(
            workspaceSlug: widget.workspaceSlug,
            entity: FavoriteEntity.cycle,
            entityId: cycle.id,
            entityName: cycle.name,
            projectId: widget.projectId,
          ),
          if (archived)
            M3EIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Restore cycle ${cycle.name}',
              size: M3EIconButtonSize.small,
              onPressed: () => _confirmUnarchive(cycle),
            ),
        ],
      ),
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
    final ok = await confirmAction(
      context,
      title: 'Restore cycle',
      message: 'Move "${cycle.name}" back into the active cycles?',
      confirmLabel: 'Restore',
    );
    if (ok) await _unarchive(cycle);
  }
}
