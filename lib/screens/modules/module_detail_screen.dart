import 'package:flutter/material.dart';
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
import '../../widgets/loading_state.dart';
import '../../widgets/issue_tile.dart';
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
  ConsumerState<ModuleDetailScreen> createState() =>
      _ModuleDetailScreenState();
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
      final states = cache.getStates(widget.workspaceSlug, widget.projectId) ?? {};
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
        _allProjectIssues = _cache.getIssues(widget.workspaceSlug, widget.projectId) ?? [];
        if (_allProjectIssues.isEmpty) {
          final result = await IssueService.getIssues(
              widget.workspaceSlug, widget.projectId);
          _allProjectIssues = result['issues'] as List<Issue>;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load issues')),
          );
        }
        return;
      }
    }

    final existingIds = _issues.map((i) => i.id).toSet();
    final available =
        _allProjectIssues.where((i) => !existingIds.contains(i.id)).toList();
    final selected = <String>{};

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) => SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('Add issues',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                try {
                                  await ModuleService.addIssuesToModule(
                                    widget.workspaceSlug,
                                    widget.projectId,
                                    widget.module.id,
                                    selected.toList(),
                                  );
                                  _load();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to add issues: $e')),
                                    );
                                  }
                                }
                              },
                        child: Text('Add (${selected.length})'),
                      ),
                    ],
                  ),
                ),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No more issues to add'),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: available.length,
                    itemBuilder: (ctx, i) {
                      final issue = available[i];
                      return CheckboxListTile(
                        value: selected.contains(issue.id),
                        onChanged: (v) {
                          setSheetState(() {
                            if (v == true) {
                              selected.add(issue.id);
                            } else {
                              selected.remove(issue.id);
                            }
                          });
                        },
                        title: Text(issue.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodyMedium),
                        secondary: Icon(
                          PlaneTheme.priorityIcon(issue.priority),
                          size: 16,
                          color: PlaneTheme.priorityColor(context, issue.priority),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeIssue(Issue issue) async {
    try {
      await ModuleService.removeIssueFromModule(
        widget.workspaceSlug,
        widget.projectId,
        widget.module.id,
        issue.id,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove issue: $e')),
        );
      }
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
                  onChanged: (v) => setDialogState(
                      () => selectedStatus = v ?? 'backlog'),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Module updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete module'),
        content: const Text('Are you sure you want to delete this module?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ModuleService.deleteModule(
                  widget.workspaceSlug,
                  widget.projectId,
                  widget.module.id,
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
    final statusColor = _statusColorFor(mod.status);

    return Scaffold(
      appBar: M3EAppBar(
        title: mod.name,
        actions: [
          M3EAppBarAction(
            icon: Icons.more_horiz,
            tooltip: 'More',
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
                            // Status chip
                            PropertyChip(
                              icon: Icons.circle,
                              iconColor: statusColor,
                              label: _statusLabel(mod.status),
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
                            if (mod.startDate != null ||
                                mod.targetDate != null)
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: PlaneTheme.iconSmall, color: secondary),
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
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
                      Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: theme.colorScheme.outlineVariant),
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
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No issues in this module',
                                style: theme.textTheme.bodySmall),
                          ),
                        ),
                      ..._issues.map((issue) => Dismissible(
                            key: ValueKey(issue.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 20),
                              color: Colors.red.withValues(alpha: 0.1),
                              child: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: PlaneTheme.iconLarge),
                            ),
                            confirmDismiss: (_) async {
                              await _removeIssue(issue);
                              return false;
                            },
                            child: IssueTile(
                              issue: issue,
                              state: _states[issue.state],
                              showPriority: true,
                              showState: true,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => IssueDetailScreen(
                                      workspaceSlug:
                                          widget.workspaceSlug,
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

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text('Edit module',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showEditModuleDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              title: Text('Delete module',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
