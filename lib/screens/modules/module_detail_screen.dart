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
import '../../services/module_service.dart';
import '../../services/issue_service.dart';
import '../../providers/data_providers.dart';
import '../../models/module.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/property_chip.dart';
import '../issues/issue_detail_screen.dart';

/// The status dropdown's decoration, mirroring [M3ETextField] exactly.
///
/// A dropdown cannot be wrapped in [M3ETextField], so the one treatment is
/// mirrored here instead — same corner, same 0.8 outline, same fill — and shared
/// with the create dialog in `module_list_screen.dart` so the two forms match.
InputDecoration moduleStatusFieldDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(M3EShape.large),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: 'Status',
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(scheme.outlineVariant, 0.8),
    enabledBorder: border(scheme.outlineVariant, 0.8),
    focusedBorder: border(scheme.primary, 1.6),
  );
}

class ModuleDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final Module module;

  const ModuleDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.module,
  });

  @override
  ConsumerState<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends ConsumerState<ModuleDetailScreen> {
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
      // Load states from shared cache (deduped) + module issues in parallel
      final cache = _cache;
      final results = await Future.wait([
        ModuleService.getModuleIssues(
            widget.workspaceSlug, widget.projectId, widget.module.id),
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
      await ModuleService.addIssuesToModule(
        widget.workspaceSlug,
        widget.projectId,
        widget.module.id,
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

  /// Takes an issue out of the module, and leaves the door open.
  ///
  /// Removal was one tap on a button that sits in every row, with no
  /// confirmation and no way back: the request went out, the list reloaded,
  /// and an issue a user did not mean to touch was simply gone from the
  /// module. Material's answer to a reversible destructive action is not a
  /// dialog in front of it but an undo behind it, which is what [sayUndo]
  /// offers here.
  ///
  /// The row leaves before the request does. Undo only means anything if the
  /// user is not left watching a spinner to learn whether the mistake
  /// happened; a failure puts the row back at the index it left from and says
  /// why.
  Future<void> _removeIssue(Issue issue) async {
    final index = _issues.indexWhere((i) => i.id == issue.id);
    if (index < 0) return;
    setState(() => _issues.removeAt(index));
    try {
      await ModuleService.removeIssueFromModule(
        widget.workspaceSlug,
        widget.projectId,
        widget.module.id,
        issue.id,
      );
      if (!mounted) return;
      sayUndo(
        context,
        'Removed ${issue.name} from this module',
        () => _restoreIssue(issue, index),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _issues.insert(index.clamp(0, _issues.length), issue));
      sayError(
          context, describeApiError(e, fallback: 'Failed to remove issue'));
    }
  }

  /// Undo: puts the issue back, in the same place and by the same rules.
  ///
  /// The list is not reloaded on the way — a full `_load()` would blank the
  /// screen to a spinner, which is the opposite of what an undo should feel
  /// like. [index] can be past the end by now if the user removed other rows
  /// in the seconds the snackbar was up, so it is clamped rather than trusted.
  Future<void> _restoreIssue(Issue issue, int index) async {
    if (_issues.any((i) => i.id == issue.id)) return;
    setState(() => _issues.insert(index.clamp(0, _issues.length), issue));
    try {
      await ModuleService.addIssuesToModule(
        widget.workspaceSlug,
        widget.projectId,
        widget.module.id,
        [issue.id],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _issues.removeWhere((i) => i.id == issue.id));
      sayError(
          context, describeApiError(e, fallback: 'Failed to restore issue'));
    }
  }

  void _showEditModuleDialog() {
    final nameController = TextEditingController(text: widget.module.name);
    final descController =
        TextEditingController(text: widget.module.description ?? '');
    String selectedStatus = widget.module.status ?? 'backlog';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit module'),
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
                      setDialogState(() => selectedStatus = v ?? 'backlog'),
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
                  await ModuleService.updateModule(
                    widget.workspaceSlug,
                    widget.projectId,
                    widget.module.id,
                    {
                      'name': name,
                      'description': descController.text.trim(),
                      'status': selectedStatus,
                    },
                  );
                  if (mounted) {
                    say(context, 'Module updated');
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
      ),
    );
  }

  Future<void> _confirmArchive() async {
    // Reversible, so not the error role — see the cycle screen's twin.
    final ok = await confirmAction(
      context,
      title: 'Archive module',
      message:
          'Move "${widget.module.name}" out of the active modules? It stays '
          'readable under Archived and can be restored from there.',
      confirmLabel: 'Archive',
    );
    if (!ok) return;
    try {
      await ModuleService.archiveModule(
          widget.workspaceSlug, widget.projectId, widget.module.id);
      // The list screen invalidates and reloads on every return from here.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to archive'));
      }
    }
  }

  Future<void> _unarchive() async {
    try {
      await ModuleService.unarchiveModule(
          widget.workspaceSlug, widget.projectId, widget.module.id);
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
      title: 'Delete module',
      message: 'Are you sure you want to delete this module? '
          'The work items in it are not deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ModuleService.deleteModule(
        widget.workspaceSlug,
        widget.projectId,
        widget.module.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context, describeApiError(e, fallback: 'Failed to delete'));
      }
    }
  }

  Color _statusColorFor(String? status) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final mod = widget.module;
    final statusColor =
        mod.isArchived ? secondary : _statusColorFor(mod.status);

    return Scaffold(
      appBar: M3EAppBar(
        title: mod.name,
        actions: [
          M3EAppBarAction(
            icon: Icons.more_horiz,
            // Names the target, not the glyph: the cycle screen carries the
            // same overflow trigger, and two nodes both called "More" make
            // `adb_drive.py tap "More"` ambiguous across a flow.
            tooltip: 'More actions for module ${mod.name}',
            onPressed: () => _showMoreMenu(),
          ),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load module issues',
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      // Module info
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status chip. An archived module keeps its status
                            // — completed and cancelled are not the same
                            // thing — so Archived is a second chip beside it
                            // rather than a replacement.
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                PropertyChip(
                                  icon: Icons.circle,
                                  iconColor: statusColor,
                                  label: _statusLabel(mod.status),
                                ),
                                if (mod.isArchived)
                                  PropertyChip(
                                    icon: Icons.inventory_2_outlined,
                                    iconColor: secondary,
                                    label: 'Archived',
                                  ),
                              ],
                            ),
                            if (mod.description != null &&
                                mod.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(mod.description!,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(color: secondary)),
                            ],
                            const SizedBox(height: 12),
                            // Date range
                            if (mod.startDate != null || mod.targetDate != null)
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: PlaneTheme.iconSmall,
                                      color: secondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    [mod.startDate, mod.targetDate]
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
                                      value: mod.progress,
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
                                  '${mod.completedIssues}/${mod.totalIssues}',
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
                              tooltip: 'Add issues to module',
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
                            message: 'No issues in this module',
                            icon: Icons.view_module_outlined,
                            subtitle: 'Add the work items that ship it',
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
                            // The swipe removes the row and the removal takes
                            // it out of the list, so this is `onDismissed`
                            // rather than a `confirmDismiss` that awaits the
                            // request and answers `false`: that older shape
                            // left the `Dismissible` animating itself back in
                            // while the list was already rebuilding without
                            // it.
                            onDismissed: (_) => _removeIssue(issue),
                            // Removing an issue used to be the swipe and
                            // nothing else: no button, no long-press, no
                            // custom action. A swipe produces no semantics
                            // node, so the action was not merely awkward
                            // without sight — there was nothing for
                            // `adb_drive.py check` to report as missing. The
                            // swipe stays as the accelerator.
                            //
                            // The button rides in the row's own trailing slot,
                            // which is the one part of the card outside its
                            // semantics node and so the one place a real
                            // button survives.
                            child: IssueRow(
                              issue: issue,
                              state: _states[issue.state],
                              showPriority: true,
                              showState: true,
                              trailing: M3EIconButton(
                                icon: Icons.remove_circle_outline,
                                tooltip:
                                    'Remove ${issue.name} from this module',
                                size: M3EIconButtonSize.small,
                                color: theme.colorScheme.onSurfaceVariant,
                                onPressed: () => _removeIssue(issue),
                              ),
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
                          )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showMoreMenu() async {
    final mod = widget.module;
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: mod.name,
      items: [
        // Plane answers 400 to a PATCH on an archived module, so the edit
        // entry is withheld rather than offered and then failing.
        if (!mod.isArchived)
          const BottomSheetPickerItem(
              value: 'edit', label: 'Edit module', icon: Icons.edit_outlined),
        if (mod.isArchived)
          const BottomSheetPickerItem(
            value: 'restore',
            label: 'Restore module',
            icon: Icons.unarchive_outlined,
          )
        else
          BottomSheetPickerItem(
            value: 'archive',
            label: 'Archive module',
            icon: Icons.inventory_2_outlined,
            // Plane only archives a completed or cancelled module. Shown
            // disabled with the reason: "no archive action here" and "not
            // archivable yet" are different things to a reader.
            enabled: mod.canArchive,
            subtitle:
                mod.canArchive ? null : 'Only a completed or cancelled module',
          ),
        const BottomSheetPickerItem(
          value: 'delete',
          label: 'Delete module',
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    switch (chosen) {
      case 'edit':
        _showEditModuleDialog();
      case 'restore':
        await _unarchive();
      case 'archive':
        await _confirmArchive();
      case 'delete':
        await _confirmDelete();
    }
  }
}
