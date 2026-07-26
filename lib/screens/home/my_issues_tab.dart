import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/data_providers.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../utils/issue_grouping.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/display_options.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/button_group.dart';
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

  /// Grouping, ordering and row properties, in the same object the project
  /// issue list uses. This screen used to keep seven loose fields of its own
  /// beside a 250-line copy of the sheet that wrote them.
  final DisplayState _display = DisplayState();

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
    if (_display.completedFilter == 'none') {
      result = result.where((i) {
        final group = _allStates[i.state]?.group ?? 'backlog';
        return group != 'completed' && group != 'cancelled';
      }).toList();
    } else if (_display.completedFilter == 'week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      result = result.where((i) {
        final group = _allStates[i.state]?.group ?? 'backlog';
        if (group != 'completed' && group != 'cancelled') return true;
        return i.updatedAt.isAfter(weekAgo);
      }).toList();
    }
    if (!_display.showSubIssues) {
      result = result.where((i) => i.parent == null).toList();
    }
    result = applySorting(result, _display.sortField, !_display.sortNewest);
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
      _display.groupByField,
      _filteredAndSorted,
      _allStates,
      members: _allMembers,
      labels: _allLabels,
    );
  }

  Color _groupColor(String key) {
    switch (_display.groupByField) {
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

  Future<void> _createIssue() async {
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
    // A work item belongs to exactly one project, so which one is a single
    // choice — the shared picker, rather than a fifth hand-rolled sheet.
    final chosen = await BottomSheetPicker.show<Project>(
      context: context,
      title: 'New issue',
      subtitle: 'Which project?',
      items: projects
          .map((p) => BottomSheetPickerItem(
                value: p,
                label: p.name,
                subtitle: p.identifier,
                icon: Icons.folder_outlined,
              ))
          .toList(),
    );
    if (chosen != null) _openCreateScreen(chosen);
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

  Future<void> _showOptionsMenu() async {
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: 'List options',
      items: const [
        BottomSheetPickerItem(
            value: 'display', label: 'Display options', icon: Icons.tune),
        BottomSheetPickerItem(
            value: 'refresh', label: 'Refresh', icon: Icons.refresh),
      ],
    );
    switch (chosen) {
      case 'display':
        _showDisplayOptions();
      case 'refresh':
        _load();
    }
  }

  /// The shared sheet. This screen used to carry its own 250-line copy of it,
  /// which had already drifted in five ways — and whose "Grouping" row wrote a
  /// field the list below never read.
  void _showDisplayOptions() =>
      showDisplayOptions(context, _display, () => setState(() {}));

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
        // The same component sits at 48 on issues_tab_screen. Three segments
        // are the screen's primary navigation and each one was a 40dp target;
        // the connected group has no padded hit area behind it to make up the
        // difference, so the height *is* the target.
        height: kMinInteractiveDimension,
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
    // Grouped by whatever the display sheet says, which is the whole point of
    // that row. It used to group by state group unconditionally, so choosing
    // "Priority", "Assignee" or "Label" changed the word on the sheet and
    // nothing else on the screen.
    final grouped = _grouped;
    if (grouped.isEmpty) {
      return const ScrollableEmptyState(
        message: 'No issues',
        icon: Icons.check_circle_outline,
        subtitle: 'All caught up',
        padding: EdgeInsets.only(bottom: 100),
      );
    }

    final items = <Widget>[];
    for (final entry in grouped.entries) {
      items.add(SectionHeader(
        label: groupByLabel(_display.groupByField, entry.key),
        // Every other call site shows the count pill.
        count: entry.value.length,
        color: _groupColor(entry.key),
      ));
      for (final issue in entry.value) {
        final state = _allStates[issue.state];
        items.add(IssueRow(
          issue: issue,
          state: state,
          identifier: _projectIdentifiers[issue.project],
          showPriority: _display.rowProperties.contains('priority'),
          showState: _display.rowProperties.contains('status'),
          showId: true,
          showLabels: _display.rowProperties.contains('labels'),
          showProject: _display.rowProperties.contains('project'),
          showDueDate: _display.rowProperties.contains('due_date'),
          showAssignee: _display.rowProperties.contains('assignee'),
          maxTitleLines: _display.maxTitleLines,
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
