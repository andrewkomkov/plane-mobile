import 'package:flutter/material.dart';
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
                      const Text('Add issues',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
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
                            style: const TextStyle(fontSize: 14)),
                        secondary: Icon(
                          PlaneTheme.priorityIcon(issue.priority),
                          size: 16,
                          color: PlaneTheme.priorityColor(issue.priority),
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
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
      appBar: AppBar(
        title: Text(mod.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 20),
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
                                  style: TextStyle(
                                      fontSize: PlaneTheme.fontBody, color: secondary)),
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
                                    style: TextStyle(
                                        fontSize: PlaneTheme.fontSection, color: secondary),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            // Progress
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: mod.progress,
                                      minHeight: 6,
                                      backgroundColor: theme
                                          .colorScheme.outline
                                          .withValues(alpha: 0.3),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              statusColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${mod.completedIssues}/${mod.totalIssues}',
                                  style: TextStyle(
                                      fontSize: PlaneTheme.fontSection, color: secondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Issues header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Row(
                          children: [
                            Text('Issues',
                                style: TextStyle(
                                    fontSize: PlaneTheme.fontSection,
                                    fontWeight: PlaneTheme.fontSectionWeight,
                                    color: secondary)),
                            const SizedBox(width: 6),
                            Text('${_issues.length}',
                                style: TextStyle(
                                    fontSize: PlaneTheme.fontCaption, color: secondary)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showAddIssuesSheet,
                              child: Icon(Icons.add,
                                  size: PlaneTheme.iconLarge, color: secondary),
                            ),
                          ],
                        ),
                      ),
                      if (_issues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No issues in this module',
                                style: TextStyle(
                                    fontSize: PlaneTheme.fontSection, color: secondary)),
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
              title: const Text('Edit module',
                  style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditModuleDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              title: const Text('Delete module',
                  style: TextStyle(color: Colors.red, fontSize: 14)),
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
