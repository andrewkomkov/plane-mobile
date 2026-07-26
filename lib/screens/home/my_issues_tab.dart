import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/data_providers.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../utils/issue_grouping.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/button_group.dart';
import '../../widgets/m3e/chip.dart';
import '../../widgets/m3e/fab_menu.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/issue_row.dart';
import '../issues/issue_detail_screen.dart';
import '../issues/issue_create_screen.dart';
import '../../models/project.dart';

class MyIssuesTab extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String? currentUserId;
  const MyIssuesTab(
      {super.key, required this.workspaceSlug, this.currentUserId});

  @override
  ConsumerState<MyIssuesTab> createState() => _MyIssuesTabState();
}

class _MyIssuesTabState extends ConsumerState<MyIssuesTab>
    with AutomaticKeepAliveClientMixin {
  List<Issue> _issues = [];
  Map<String, IssueState> _allStates = {};
  Map<String, String> _projectIdentifiers = {}; // project_id → identifier
  List<Label> _allLabels = [];
  List<Member> _allMembers = [];
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  FilterState _filterState = const FilterState();

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyIssuesTab old) {
    super.didUpdateWidget(old);
    if (old.workspaceSlug != widget.workspaceSlug) _load();
  }

  Future<void> _load() async {
    if (widget.workspaceSlug.isEmpty) return;
    if (!_loaded) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Get projects from shared cache
      final cache = _cache;
      await cache.loadProjects(widget.workspaceSlug);
      final projects = cache.getProjects(widget.workspaceSlug) ?? [];
      _projectIdentifiers = {for (final p in projects) p.id: p.identifier};

      // Load issues from each project — show results progressively
      final allIssues = <Issue>[];
      final allStates = <String, IssueState>{};

      final coreFutures = projects.map((p) async {
        try {
          await cache.loadProjectCoreData(widget.workspaceSlug, p.id);
          final states = cache.getStates(widget.workspaceSlug, p.id) ?? {};
          final issues = cache.getIssues(widget.workspaceSlug, p.id) ?? [];
          allStates.addAll(states);
          allIssues.addAll(issues);
          if (mounted && _loading) {
            setState(() {
              _issues = List.from(allIssues);
              _allStates = Map.from(allStates);
              _loading = false;
              _loaded = true;
            });
          }
        } catch (_) {}
      }).toList();

      await Future.wait(coreFutures);

      if (mounted) {
        setState(() {
          _issues = allIssues;
          _allStates = allStates;
          _loading = false;
          _loaded = true;
          _error = null;
        });
      }

      _loadExtras(projects);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _hasStateFilterForDone {
    if (_filterState.selectedStates.isEmpty) return false;
    return _filterState.selectedStates.any((stateId) {
      final state = _allStates[stateId];
      return state != null &&
          (state.group == 'completed' || state.group == 'cancelled');
    });
  }

  List<Issue> get _filteredAndSorted {
    var result = _issues.toList();
    if (_filterMode == 'assigned' && widget.currentUserId != null) {
      result = result
          .where((i) => i.assignees.contains(widget.currentUserId))
          .toList();
    } else if (_filterMode == 'created' && widget.currentUserId != null) {
      result =
          result.where((i) => i.createdBy == widget.currentUserId).toList();
    }
    // 'all' mode: no user filtering — show all issues from all projects
    result = applyFilters(result, _filterState);
    if (_completedFilter == 'none') {
      result = result.where((i) {
        final group = _allStates[i.state]?.group ?? 'backlog';
        return group != 'completed' && group != 'cancelled';
      }).toList();
    } else if (_completedFilter == 'week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      result = result.where((i) {
        final group = _allStates[i.state]?.group ?? 'backlog';
        if (group != 'completed' && group != 'cancelled') return true;
        return i.updatedAt.isAfter(weekAgo);
      }).toList();
    }
    if (!_showSubIssues) {
      result = result.where((i) => i.parent == null).toList();
    }
    result = applySorting(
        result, _filterState.sortField, _filterState.sortAscending);
    return result;
  }

  Future<void> _loadExtras(List projects) async {
    // Reached from _load after an await, so the tab may already be gone by the
    // time this runs — and `_cache` is a ref.read, which throws on a disposed
    // element rather than returning null. The tail of this method already
    // checks mounted; the head has to as well.
    if (!mounted) return;
    final cache = _cache;
    final allLabels = <Label>[];
    final allMembers = <Member>[];
    final seenLabelIds = <String>{};
    final seenMemberIds = <String>{};
    for (final p in projects) {
      try {
        await cache.loadProjectExtras(widget.workspaceSlug, p.id);
        for (final l
            in cache.getLabels(widget.workspaceSlug, p.id) ?? <Label>[]) {
          if (seenLabelIds.add(l.id)) allLabels.add(l);
        }
        for (final m
            in cache.getMembers(widget.workspaceSlug, p.id) ?? <Member>[]) {
          if (seenMemberIds.add(m.id)) allMembers.add(m);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _allLabels = allLabels;
        _allMembers = allMembers;
      });
    }
  }

  Map<String, List<Issue>> get _grouped {
    return groupIssuesBy(
      _filterState.groupBy,
      _filteredAndSorted,
      _allStates,
      members: _allMembers,
      labels: _allLabels,
    );
  }

  Color _groupColor(String key) {
    switch (_filterState.groupBy) {
      case GroupByField.state:
        return PlaneTheme.stateGroupColor(context, key);
      case GroupByField.priority:
        return PlaneTheme.priorityColor(context, key);
      case GroupByField.assignee:
      case GroupByField.label:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _filterMode = 'assigned';

  void _createIssue() {
    final cache = _cache;
    final projects = cache.getProjects(widget.workspaceSlug) ?? [];
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No projects available')),
      );
      return;
    }
    if (projects.length == 1) {
      _openCreateScreen(projects.first);
      return;
    }
    // Show project picker
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select project',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ...projects.map((p) => ListTile(
                  leading: const Icon(Icons.folder_outlined, size: 20),
                  title: Text('${p.identifier} - ${p.name}',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCreateScreen(p);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openCreateScreen(Project project) async {
    final cache = _cache;
    await cache.loadProjectCoreData(widget.workspaceSlug, project.id);
    final states = cache.getStates(widget.workspaceSlug, project.id) ?? {};
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: project.id,
          states: states,
        ),
      ),
    );
    _load();
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune, size: 20),
              title: Text('Display options',
                  style: Theme.of(ctx).textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(ctx);
                _showDisplayOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, size: 20),
              title: Text('Refresh', style: Theme.of(ctx).textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(ctx);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _grouping = 'state';
  String _ordering = 'created';
  bool _sortNewest = true;
  String _completedFilter = 'none';
  bool _showSubIssues = true;
  int _maxTitleLines = 1;
  Set<String> _rowProperties = {'status', 'priority', 'id'};

  void _showDisplayOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final secondary = theme.colorScheme.onSurfaceVariant;

          Widget optionRow(String label, String value, VoidCallback onTap) {
            return InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Text(label, style: theme.textTheme.bodyLarge),
                    const Spacer(),
                    Text(value,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: secondary)),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more,
                        size: PlaneTheme.iconMedium, color: secondary),
                  ],
                ),
              ),
            );
          }

          void cycleOption(String field, List<(String, String)> options,
              String current, Function(String) onChanged) {
            final idx = options.indexWhere((o) => o.$1 == current);
            final next = options[(idx + 1) % options.length];
            onChanged(next.$1);
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: secondary.withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(M3EShape.full)))),
                  const SizedBox(height: 16),
                  optionRow('Grouping',
                      _grouping[0].toUpperCase() + _grouping.substring(1), () {
                    setSheetState(() {
                      cycleOption(
                          'grouping',
                          [
                            ('state', 'Status'),
                            ('priority', 'Priority'),
                            ('assignee', 'Assignee'),
                            ('label', 'Label')
                          ],
                          _grouping,
                          (v) => _grouping = v);
                    });
                    setState(() {
                      _filterState = FilterState(
                          groupBy: {
                                'state': GroupByField.state,
                                'priority': GroupByField.priority,
                                'assignee': GroupByField.assignee,
                                'label': GroupByField.label,
                              }[_grouping] ??
                              GroupByField.state);
                    });
                  }),
                  optionRow('Ordering',
                      _ordering[0].toUpperCase() + _ordering.substring(1), () {
                    setSheetState(() {
                      cycleOption(
                          'ordering',
                          [
                            ('created', 'Created'),
                            ('updated', 'Updated'),
                            ('priority', 'Priority')
                          ],
                          _ordering, (v) {
                        _ordering = v;
                      });
                    });
                    setState(() {
                      _filterState = FilterState(
                        groupBy: _filterState.groupBy,
                        sortField: _ordering == 'updated'
                            ? SortField.updatedAt
                            : _ordering == 'priority'
                                ? SortField.priority
                                : SortField.createdAt,
                        sortAscending: !_sortNewest,
                      );
                    });
                  }),
                  optionRow(
                      'Sort', _sortNewest ? 'Newest first' : 'Oldest first',
                      () {
                    setSheetState(() => _sortNewest = !_sortNewest);
                    setState(() {
                      _filterState = FilterState(
                        groupBy: _filterState.groupBy,
                        sortField: _filterState.sortField,
                        sortAscending: !_sortNewest,
                      );
                    });
                  }),
                  const SizedBox(height: 8),
                  optionRow(
                      'Completed issues',
                      _completedFilter == 'none'
                          ? 'None'
                          : _completedFilter == 'week'
                              ? 'Past week'
                              : 'All', () {
                    setSheetState(() {
                      cycleOption(
                          'completed',
                          [
                            ('none', 'None'),
                            ('week', 'Past week'),
                            ('all', 'All')
                          ],
                          _completedFilter,
                          (v) => _completedFilter = v);
                    });
                    setState(() {});
                  }),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Text('Show sub-issues',
                            style: theme.textTheme.bodyLarge),
                        const Spacer(),
                        // The switch sits in a Row next to its caption, so it
                        // would otherwise be an unnamed node for automation.
                        Semantics(
                          label: 'Show sub-issues',
                          child: Switch(
                            value: _showSubIssues,
                            onChanged: (v) {
                              setSheetState(() => _showSubIssues = v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  optionRow('Maximum title length',
                      '$_maxTitleLines line${_maxTitleLines > 1 ? 's' : ''}',
                      () {
                    setSheetState(
                        () => _maxTitleLines = _maxTitleLines == 1 ? 2 : 1);
                    setState(() {});
                  }),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text('Row properties',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: secondary)),
                        const Spacer(),
                        // A TextButton rather than a bare tap target: it
                        // carries the 48dp minimum without extra layout.
                        TextButton(
                          onPressed: () {
                            setSheetState(() =>
                                _rowProperties = {'status', 'priority', 'id'});
                            setState(() {});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: secondary,
                            minimumSize: const Size(48, 48),
                            textStyle:
                                M3EType.emphasized(theme.textTheme.titleSmall!),
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final prop in [
                          'Status',
                          'Priority',
                          'Assignee',
                          'ID',
                          'Labels',
                          'Project',
                          'Due date',
                          'Cycle',
                          'Estimate'
                        ])
                          // The chip's Text names it; only the on/off state
                          // needs exposing, as it is carried by colour alone.
                          Semantics(
                            button: true,
                            selected: _rowProperties.contains(
                                prop.toLowerCase().replaceAll(' ', '_')),
                            child: M3EChip(
                              label: prop,
                              selected: _rowProperties.contains(
                                  prop.toLowerCase().replaceAll(' ', '_')),
                              onTap: () {
                                final key =
                                    prop.toLowerCase().replaceAll(' ', '_');
                                setSheetState(() {
                                  if (_rowProperties.contains(key)) {
                                    _rowProperties.remove(key);
                                  } else {
                                    _rowProperties.add(key);
                                  }
                                });
                                setState(() {});
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return M3EFlexibleHeaderScaffold(
      title: 'My issues',
      actions: [
        M3EIconButton(
          icon: Icons.more_horiz,
          tooltip: 'Open list options',
          onPressed: _showOptionsMenu,
        ),
      ],
      // The three scopes are mutually exclusive and equally weighted — exactly
      // what a connected ButtonGroup is for. It also gives the row the press
      // give-and-take that separate pills could not.
      bottom: M3EButtonGroup(
        height: 40,
        items: const [
          M3EButtonGroupItem(label: 'Assigned'),
          M3EButtonGroupItem(label: 'Created'),
          M3EButtonGroupItem(label: 'All'),
        ],
        selectedIndex: _filterModes.indexOf(_filterMode),
        onSelected: (i) => setState(() => _filterMode = _filterModes[i]),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const IssueListSkeleton()
                : _error != null
                    ? ErrorStateWidget(
                        message: 'Failed to load', onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _buildLinearList(),
                      ),
          ),
          Positioned(
            right: 20,
            bottom: 96,
            child: M3EFabMenu(
              actions: [
                M3EFabAction(
                  label: 'New issue',
                  icon: Icons.edit_square,
                  onPressed: _createIssue,
                ),
                M3EFabAction(
                  label: 'Display options',
                  icon: Icons.tune,
                  onPressed: _showDisplayOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _filterModes = ['assigned', 'created', 'all'];

  Widget _buildLinearList() {
    final grouped = groupIssuesByStateGroup(_filteredAndSorted, _allStates);
    if (grouped.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Center(
          child: EmptyStateWidget(
            message: 'No issues',
            icon: Icons.check_circle_outline,
            subtitle: 'All caught up',
          ),
        ),
      ]);
    }

    final items = <Widget>[];
    for (final entry in grouped.entries) {
      items.add(SectionHeader(
        label: groupLabel(entry.key),
        color: PlaneTheme.stateGroupColor(context, entry.key),
      ));
      for (final issue in entry.value) {
        final state = _allStates[issue.state];
        items.add(IssueRow(
          issue: issue,
          state: state,
          identifier: _projectIdentifiers[issue.project],
          showPriority: _rowProperties.contains('priority'),
          showState: _rowProperties.contains('status'),
          showId: true,
          showLabels: _rowProperties.contains('labels'),
          showProject: _rowProperties.contains('project'),
          showDueDate: _rowProperties.contains('due_date'),
          showAssignee: _rowProperties.contains('assignee'),
          maxTitleLines: _maxTitleLines,
          onTap: () async {
            if (issue.project == null) return;
            await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssueDetailScreen(
                    workspaceSlug: widget.workspaceSlug,
                    projectId: issue.project!,
                    issueId: issue.id,
                    states: _allStates,
                  ),
                ));
            _load();
          },
        ));
      }
    }
    items.add(const SizedBox(height: 100));

    return ListView(children: items);
  }
}
