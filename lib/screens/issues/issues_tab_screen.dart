import 'package:flutter/material.dart';
import '../../widgets/m3e/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../providers/data_providers.dart';
import '../../widgets/skeleton_loader.dart';
import 'issue_list_screen.dart';
import 'kanban_board_screen.dart';
import 'spreadsheet_view.dart';
import 'calendar_view.dart';


enum _ViewMode { list, kanban, spreadsheet, calendar }

class IssuesTabScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;

  const IssuesTabScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
  });

  @override
  ConsumerState<IssuesTabScreen> createState() =>
      _IssuesTabScreenState();
}

class _IssuesTabScreenState extends ConsumerState<IssuesTabScreen>
    with AutomaticKeepAliveClientMixin {
  _ViewMode _viewMode = _ViewMode.list;
  bool _initialLoading = true;

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = _cache;
    // Load states + issues in parallel (deduped by cache)
    await cache.loadProjectCoreData(widget.workspaceSlug, widget.projectId);
    if (mounted) setState(() => _initialLoading = false);
    // Load labels + members in background
    await cache.loadProjectExtras(widget.workspaceSlug, widget.projectId);
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final cache = _cache;
    await cache.refreshProjectCoreData(widget.workspaceSlug, widget.projectId);
    if (mounted) setState(() {});
    await cache.loadProjectExtras(widget.workspaceSlug, widget.projectId);
    if (mounted) setState(() {});
  }

  List<Issue> get _issues =>
      _cache.getIssues(widget.workspaceSlug, widget.projectId) ?? [];
  Map<String, IssueState> get _states =>
      _cache.getStates(widget.workspaceSlug, widget.projectId) ?? {};
  List<Label> get _labels =>
      _cache.getLabels(widget.workspaceSlug, widget.projectId) ?? [];
  List<Member> get _members =>
      _cache.getMembers(widget.workspaceSlug, widget.projectId) ?? [];

  bool get _fromCache {
    final cache = _cache;
    return cache.isIssuesLoading(widget.workspaceSlug, widget.projectId) &&
        _issues.isNotEmpty;
  }

  bool get _refreshing =>
      _cache.isIssuesLoading(widget.workspaceSlug, widget.projectId) &&
      _issues.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoading && _issues.isEmpty) {
      return const IssueListSkeleton();
    }

    return Column(
      children: [
        // View toggle row. Four mutually exclusive views of the same data, so
        // this is the real androidx ButtonGroup from material3 1.5.0-alpha24,
        // rendered by Compose in a platform view (see widgets/m3e/native.dart).
        // Off Android it falls back to the Dart M3EButtonGroup.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: M3ENativeButtonGroup(
            height: 48,
            labels: const ['List', 'Board', 'Table', 'Calendar'],
            selectedIndex: _ViewMode.values.indexOf(_viewMode),
            onSelected: (i) =>
                setState(() => _viewMode = _ViewMode.values[i]),
          ),
        ),
        Expanded(child: _buildView()),
      ],
    );
  }

  Widget _buildView() {
    switch (_viewMode) {
      case _ViewMode.list:
        return IssueListScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          projectIdentifier: widget.projectIdentifier,
          issues: _issues,
          states: _states,
          labels: _labels,
          members: _members,
          onRefresh: _refresh,
        );
      case _ViewMode.kanban:
        return KanbanBoardScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          projectIdentifier: widget.projectIdentifier,
          issues: _issues,
          states: _states,
          onRefresh: _refresh,
        );
      case _ViewMode.spreadsheet:
        return SpreadsheetView(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          projectIdentifier: widget.projectIdentifier,
          issues: _issues,
          states: _states,
          allMembers: _members,
          onRefresh: _refresh,
        );
      case _ViewMode.calendar:
        return CalendarView(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          projectIdentifier: widget.projectIdentifier,
          issues: _issues,
          states: _states,
          allLabels: _labels,
          allMembers: _members,
          onRefresh: _refresh,
        );
    }
  }
}
