import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/issue.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/project.dart';
import '../../models/state.dart';
import '../../models/workspace_rollup.dart';
import '../../services/project_service.dart';
import '../../services/workspace_rollup_service.dart';
import '../../services/workspace_service.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../issues/issue_detail_screen.dart';

/// Every work item in the workspace, across every project the caller is in.
///
/// The app is project-scoped everywhere else, which means a work item's project
/// is implied by the screen you are on. Here it is not, so every row leads with
/// the project's identifier — `PLM-123` — and names the project underneath. A
/// row that said only "Fix the login redirect" would be unidentifiable: three
/// projects can each hold one.
///
/// Doubles as the reader for a saved workspace view. A view stores its
/// selection in the same vocabulary this endpoint takes as query parameters, so
/// opening one is this screen with [view] set and the filtering done by the
/// server rather than reimplemented here.
class WorkspaceIssuesScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;

  /// The saved workspace view whose filters scope this list, if any.
  final WorkspaceView? view;

  const WorkspaceIssuesScreen({
    super.key,
    required this.workspaceSlug,
    this.view,
  });

  @override
  ConsumerState<WorkspaceIssuesScreen> createState() =>
      _WorkspaceIssuesScreenState();
}

class _WorkspaceIssuesScreenState extends ConsumerState<WorkspaceIssuesScreen> {
  /// Small enough that the first screenful arrives quickly on a workspace with
  /// thousands of work items. The server would allow 1000 and default to it.
  static const int _perPage = 50;

  /// How close to the bottom the list gets before the next page is asked for.
  /// A page of 50 rows is roughly ten screens, so a whole screen of runway is
  /// enough to hide the request.
  static const double _prefetchExtent = 600;

  final ScrollController _scroll = ScrollController();

  List<Issue> _issues = [];
  Map<String, Project> _projects = {};
  Map<String, IssueState> _states = {};
  List<Label> _labels = [];
  List<Member> _members = [];

  String? _nextCursor;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _filters => widget.view?.filters ?? const {};

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < _prefetchExtent) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Four independent reads. States and labels have to come from the
      // workspace routes rather than the project ones the rest of the app
      // uses: the ids on these rows come from every project at once, and a
      // single project's states resolve almost none of them.
      final results = await Future.wait([
        WorkspaceRollupService.getIssues(
          widget.workspaceSlug,
          perPage: _perPage,
          filters: _filters,
        ),
        ProjectService.getProjects(widget.workspaceSlug),
        WorkspaceRollupService.getStates(widget.workspaceSlug),
        WorkspaceRollupService.getLabels(widget.workspaceSlug),
        WorkspaceService.getWorkspaceMembers(widget.workspaceSlug),
      ]);
      if (!mounted) return;
      final page = results[0] as WorkspaceIssuePage;
      final projects = results[1] as List<Project>;
      setState(() {
        _issues = page.issues;
        _nextCursor = page.nextCursor;
        _total = page.totalCount;
        _projects = {for (final p in projects) p.id: p};
        _states = results[2] as Map<String, IssueState>;
        _labels = results[3] as List<Label>;
        _members = results[4] as List<Member>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await WorkspaceRollupService.getIssues(
        widget.workspaceSlug,
        cursor: cursor,
        // The paginator takes its limit from per_page and its offset from the
        // cursor, so the two have to agree across pages or rows are skipped.
        perPage: _perPage,
        filters: _filters,
      );
      if (!mounted) return;
      setState(() {
        _issues = [..._issues, ...page.issues];
        _nextCursor = page.nextCursor;
        _total = page.totalCount;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed page is not a failed screen: what has already loaded stays,
      // and the cursor stays put so scrolling again retries.
      setState(() => _loadingMore = false);
    }
  }

  /// The server's total, not the number of rows loaded — this list pages, and
  /// a count that grew as you scrolled would be reporting the paging rather
  /// than the workspace.
  String? get _subtitle {
    if (_loading) return null;
    final noun = _total == 1 ? 'work item' : 'work items';
    return '$_total $noun';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: widget.view?.name ?? 'All work items',
        subtitle: _subtitle,
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load work items', onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _list()),
    );
  }

  Widget _list() {
    if (_issues.isEmpty) {
      return ScrollableEmptyState(
        message: widget.view == null
            ? 'No work items in this workspace'
            : 'No work items match this view',
        icon: Icons.check_circle_outline,
        subtitle: widget.view == null
            ? 'Work items from every project you belong to appear here'
            : 'This view\'s filters match nothing right now',
      );
    }

    return ListView.builder(
      controller: _scroll,
      // A first page shorter than the viewport still has to be pullable.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      // One extra slot for the page-loading footer.
      itemCount: _issues.length + 1,
      itemBuilder: (ctx, i) {
        if (i == _issues.length) return _footer();
        return _issueRow(_issues[i]);
      },
    );
  }

  Widget _issueRow(Issue issue) {
    final project = issue.project != null ? _projects[issue.project] : null;

    return IssueRow(
      issue: issue,
      state: _states[issue.state],
      identifier: project?.identifier,
      // Naming the project under the title is the whole reason this row can be
      // read out of context. The identifier line above already carries the
      // short form, and that is what the accessibility label quotes.
      subtitle: project?.name,
      // With no project to prefix it, the bare sequence number is still what a
      // user would quote. `showId` defaults to "only when there is an
      // identifier", which would drop it silently.
      showId: true,
      showAssignee: true,
      showLabels: true,
      showDueDate: true,
      showSubIssues: true,
      allLabels: _labels,
      allMembers: _members,
      onTap: issue.project == null
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssueDetailScreen(
                    workspaceSlug: widget.workspaceSlug,
                    projectId: issue.project!,
                    issueId: issue.id,
                    projectIdentifier: project?.identifier ?? '',
                    states: _states,
                  ),
                ),
              );
              // Back to page one. The detail screen can change state,
              // priority, assignees and the title, and none of that reaches a
              // row that is only re-read on pull-to-refresh. Losing the scroll
              // position is the price; the list is ordered newest-first, so
              // the top is where a returning reader is anyway.
              if (mounted) _load();
            },
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: M3ELoadingIndicator(size: 24)),
      );
    }
    if (_nextCursor != null) return const SizedBox(height: 20);
    return const SizedBox(height: 8);
  }
}
