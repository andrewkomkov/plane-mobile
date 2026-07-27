import 'package:flutter/material.dart';
import '../../utils/api_error.dart';
import '../../utils/say.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/cycle_service.dart';
import '../../services/issue_service.dart';
import '../../providers/data_providers.dart';
import '../../models/cycle.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/property_chip.dart';
import '../issues/issue_detail_screen.dart';

class CycleDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final Cycle cycle;

  const CycleDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.cycle,
  });

  @override
  ConsumerState<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends ConsumerState<CycleDetailScreen> {
  List<Issue> _issues = [];
  List<Issue> _allProjectIssues = [];
  Map<String, IssueState> _states = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DataCache get _cache => ref.read(dataCacheProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load states from shared cache (deduped) + cycle issues in parallel
      final cache = _cache;
      final results = await Future.wait([
        CycleService.getCycleIssues(
            widget.workspaceSlug, widget.projectId, widget.cycle.id),
        cache.loadStates(widget.workspaceSlug, widget.projectId),
      ]);
      final states =
          cache.getStates(widget.workspaceSlug, widget.projectId) ?? {};
      setState(() {
        _issues = results[0] as List<Issue>;
        _states = states;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showAddIssuesSheet() async {
    // Load project issues from shared cache
    if (_allProjectIssues.isEmpty) {
      try {
        await _cache.loadIssues(widget.workspaceSlug, widget.projectId);
        _allProjectIssues =
            _cache.getIssues(widget.workspaceSlug, widget.projectId) ?? [];
        if (_allProjectIssues.isEmpty) {
          // Force fetch if cache is empty
          final result = await IssueService.getIssues(
              widget.workspaceSlug, widget.projectId);
          _allProjectIssues = result['issues'] as List<Issue>;
        }
      } catch (_) {
        if (mounted) {
          sayError(context, 'Failed to load issues');
        }
        return;
      }
    }

    final existingIds = _issues.map((i) => i.id).toSet();
    final available =
        _allProjectIssues.where((i) => !existingIds.contains(i.id)).toList();
    final selected = <String>{};

    if (!mounted) return;
    final chosen = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Add issues',
      selected: selected,
      emptyMessage: 'No more issues to add',
      confirmLabel: 'Add',
      showCount: true,
      requireSelection: true,
      items: [
        for (final issue in available)
          BottomSheetPickerItem(
            value: issue.id,
            label: issue.name,
            icon: PlaneTheme.priorityIcon(issue.priority),
            iconColor: PlaneTheme.priorityColor(context, issue.priority),
          ),
      ],
    );
    if (chosen == null || chosen.isEmpty) return;
    try {
      await CycleService.addIssuesToCycle(
        widget.workspaceSlug,
        widget.projectId,
        widget.cycle.id,
        chosen.toList(),
      );
      _load();
    } catch (e) {
      if (mounted) {
        sayError(
            context, describeApiError(e, fallback: 'Failed to add issues'));
      }
    }
  }

  Future<void> _removeIssue(Issue issue) async {
    try {
      await CycleService.removeIssueFromCycle(
        widget.workspaceSlug,
        widget.projectId,
        widget.cycle.id,
        issue.id,
      );
      _load();
    } catch (e) {
      if (mounted) {
        sayError(
            context, describeApiError(e, fallback: 'Failed to remove issue'));
      }
    }
  }

  void _showEditCycleDialog() {
    final nameController = TextEditingController(text: widget.cycle.name);
    final descController =
        TextEditingController(text: widget.cycle.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit cycle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3ETextField(
                label: 'Name',
                controller: nameController,
              ),
              const SizedBox(height: 12),
              M3ETextField(
                label: 'Description',
                controller: descController,
                maxLines: 2,
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
                await CycleService.updateCycle(
                  widget.workspaceSlug,
                  widget.projectId,
                  widget.cycle.id,
                  {
                    'name': name,
                    'description': descController.text.trim(),
                  },
                );
                if (mounted) {
                  say(context, 'Cycle updated');
                }
              } catch (e) {
                if (mounted) {
                  sayError(context,
                      describeApiError(e, fallback: 'Failed to update'));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchive() async {
    // Not [confirmDestructive]: archiving is reversible from the archive
    // itself, and the message says so. The error role is for what cannot be
    // undone, which on this screen is Delete.
    final ok = await confirmAction(
      context,
      title: 'Archive cycle',
      message: 'Move "${widget.cycle.name}" out of the active cycles? It stays '
          'readable under Archived and can be restored from there.',
      confirmLabel: 'Archive',
    );
    if (!ok) return;
    try {
      await CycleService.archiveCycle(
          widget.workspaceSlug, widget.projectId, widget.cycle.id);
      // The list screen invalidates and reloads on every return from here, so
      // popping is what makes the row move into the archive.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to archive'));
      }
    }
  }

  Future<void> _unarchive() async {
    try {
      await CycleService.unarchiveCycle(
          widget.workspaceSlug, widget.projectId, widget.cycle.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to restore'));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete cycle',
      message: 'Are you sure you want to delete this cycle? '
          'The work items in it are not deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await CycleService.deleteCycle(
        widget.workspaceSlug,
        widget.projectId,
        widget.cycle.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to delete'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final cycle = widget.cycle;
    final statusColor =
        cycle.isArchived ? secondary : _statusColorFor(cycle.computedStatus);

    return Scaffold(
      appBar: M3EAppBar(
        title: cycle.name,
        actions: [
          M3EAppBarAction(
            icon: Icons.more_horiz,
            // Names the target, not the glyph: the module screen carries the
            // same overflow trigger, and two nodes both called "More" make
            // `adb_drive.py tap "More"` ambiguous across a flow.
            tooltip: 'More actions for cycle ${cycle.name}',
            onPressed: () => _showMoreMenu(),
          ),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load cycle issues',
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      // Cycle info
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status chip. Archived replaces the status rather
                            // than sitting next to it: an archived cycle is
                            // always a completed one, so showing both says the
                            // same thing twice.
                            PropertyChip(
                              icon: cycle.isArchived
                                  ? Icons.inventory_2_outlined
                                  : Icons.loop,
                              iconColor: statusColor,
                              label: cycle.isArchived
                                  ? 'Archived'
                                  : cycle.computedStatus[0].toUpperCase() +
                                      cycle.computedStatus.substring(1),
                            ),
                            if (cycle.description != null &&
                                cycle.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(cycle.description!,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(color: secondary)),
                            ],
                            const SizedBox(height: 12),
                            // Date range
                            if (cycle.startDate != null ||
                                cycle.endDate != null)
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: PlaneTheme.iconSmall,
                                      color: secondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    [cycle.startDate, cycle.endDate]
                                        .where((d) => d != null)
                                        .join(' - '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            // Progress
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(M3EShape.full),
                                    child: LinearProgressIndicator(
                                      value: cycle.progress,
                                      minHeight: 6,
                                      backgroundColor:
                                          theme.colorScheme.outlineVariant,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          statusColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${cycle.completedIssues}/${cycle.totalIssues}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Bare: `dividerTheme` already says 0.5 on
                      // `outlineVariant` with no space around it, and a local
                      // copy is how two screens end up disagreeing after
                      // someone changes the token.
                      const Divider(),
                      // Issues header. The trailing add button carries its own
                      // 48dp target, so the row's vertical padding is trimmed
                      // to keep the header the same optical height as before.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                        child: Row(
                          children: [
                            Text('Issues',
                                style: M3EType.emphasized(theme
                                    .textTheme.titleSmall!
                                    .copyWith(color: secondary))),
                            const SizedBox(width: 6),
                            Text('${_issues.length}',
                                style: theme.textTheme.bodySmall),
                            const Spacer(),
                            M3EIconButton(
                              icon: Icons.add,
                              tooltip: 'Add issues to cycle',
                              size: M3EIconButtonSize.small,
                              onPressed: _showAddIssuesSheet,
                            ),
                          ],
                        ),
                      ),
                      if (_issues.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: EmptyStateWidget(
                            message: 'No issues in this cycle',
                            icon: Icons.loop,
                            subtitle: 'Add work items to plan the iteration',
                          ),
                        ),
                      ..._issues.map((issue) => Dismissible(
                            key: ValueKey(issue.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.1),
                              child: Icon(Icons.remove_circle_outline,
                                  color: theme.colorScheme.error,
                                  size: PlaneTheme.iconLarge),
                            ),
                            confirmDismiss: (_) async {
                              await _removeIssue(issue);
                              return false;
                            },
                            // Removing an issue used to be the swipe and
                            // nothing else: no button, no long-press, no
                            // custom action. A swipe produces no semantics
                            // node, so the action was not merely awkward
                            // without sight — there was nothing for
                            // `adb_drive.py check` to report as missing. The
                            // swipe stays as the accelerator.
                            //
                            // The button sits beside the row rather than in
                            // it because `IssueRow` has no trailing slot to
                            // pass through to `PlaneRow.trailing`; if it
                            // gains one, this Row collapses into it.
                            child: Row(
                              children: [
                                Expanded(
                                  child: IssueRow(
                                    issue: issue,
                                    state: _states[issue.state],
                                    showPriority: true,
                                    showState: true,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => IssueDetailScreen(
                                            workspaceSlug: widget.workspaceSlug,
                                            projectId: widget.projectId,
                                            issueId: issue.id,
                                            states: _states,
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: M3EIconButton(
                                    icon: Icons.remove_circle_outline,
                                    tooltip:
                                        'Remove ${issue.name} from this cycle',
                                    size: M3EIconButtonSize.small,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    onPressed: () => _removeIssue(issue),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showMoreMenu() async {
    final cycle = widget.cycle;
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: cycle.name,
      items: [
        // Plane rejects a PATCH on an archived cycle outright, so the edit
        // entry is not offered on one rather than being offered and failing.
        if (!cycle.isArchived)
          const BottomSheetPickerItem(
              value: 'edit', label: 'Edit cycle', icon: Icons.edit_outlined),
        if (cycle.isArchived)
          const BottomSheetPickerItem(
            value: 'restore',
            label: 'Restore cycle',
            icon: Icons.unarchive_outlined,
          )
        else
          BottomSheetPickerItem(
            value: 'archive',
            label: 'Archive cycle',
            icon: Icons.inventory_2_outlined,
            // The server only archives a cycle whose end date has passed, and
            // blows up on one with no end date at all, so the entry is shown
            // disabled with the reason rather than hidden — a cycle that
            // cannot be archived yet is not the same as one that has no
            // archive action.
            enabled: cycle.canArchive,
            subtitle: cycle.canArchive
                ? null
                : 'Only a cycle whose end date has passed',
          ),
        const BottomSheetPickerItem(
          value: 'delete',
          label: 'Delete cycle',
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    switch (chosen) {
      case 'edit':
        _showEditCycleDialog();
      case 'restore':
        await _unarchive();
      case 'archive':
        await _confirmArchive();
      case 'delete':
        await _confirmDelete();
    }
  }

  Color _statusColorFor(String status) {
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
}
