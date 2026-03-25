import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/issue_service.dart';
import '../../services/label_service.dart';
import '../../services/member_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/view.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/loading_state.dart';
import '../issues/issue_detail_screen.dart';

class ViewDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final PlaneView view;

  const ViewDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.view,
  });

  @override
  ConsumerState<ViewDetailScreen> createState() =>
      _ViewDetailScreenState();
}

class _ViewDetailScreenState extends ConsumerState<ViewDetailScreen> {
  List<Issue> _issues = [];
  Map<String, IssueState> _states = {};
  List<Label> _labels = [];
  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        IssueService.getStates(widget.workspaceSlug, widget.projectId),
        IssueService.getIssues(widget.workspaceSlug, widget.projectId),
        LabelService.getLabels(widget.workspaceSlug, widget.projectId),
        MemberService.getMembers(widget.workspaceSlug, widget.projectId),
      ]);
      final states = results[0] as List<IssueState>;
      final issueResult = results[1] as Map<String, dynamic>;
      var issues = issueResult['issues'] as List<Issue>;

      // Apply view filters from query_data
      final qd = widget.view.queryData;
      if (qd.containsKey('state') && qd['state'] is List) {
        final stateIds = (qd['state'] as List).map((e) => e.toString()).toSet();
        if (stateIds.isNotEmpty) {
          issues = issues
              .where((i) => i.state != null && stateIds.contains(i.state))
              .toList();
        }
      }
      if (qd.containsKey('priority') && qd['priority'] is List) {
        final priorities =
            (qd['priority'] as List).map((e) => e.toString()).toSet();
        if (priorities.isNotEmpty) {
          issues =
              issues.where((i) => priorities.contains(i.priority)).toList();
        }
      }
      if (qd.containsKey('assignees') && qd['assignees'] is List) {
        final assigneeIds =
            (qd['assignees'] as List).map((e) => e.toString()).toSet();
        if (assigneeIds.isNotEmpty) {
          issues = issues
              .where(
                  (i) => i.assignees.any((a) => assigneeIds.contains(a)))
              .toList();
        }
      }
      if (qd.containsKey('label') && qd['label'] is List) {
        final labelIds =
            (qd['label'] as List).map((e) => e.toString()).toSet();
        if (labelIds.isNotEmpty) {
          issues = issues
              .where((i) => i.labels.any((l) => labelIds.contains(l)))
              .toList();
        }
      }

      setState(() {
        _states = {for (var s in states) s.id: s};
        _issues = issues;
        _labels = results[2] as List<Label>;
        _members = results[3] as List<Member>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.view.name),
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load issues', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _issues.isEmpty
                      ? ListView(children: [
                          SizedBox(
                              height:
                                  MediaQuery.of(context).size.height *
                                      0.3),
                          const Center(
                            child: EmptyStateWidget(
                              message: 'No issues match this view',
                              icon: Icons.view_list_outlined,
                            ),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _issues.length,
                          separatorBuilder: (_, __) => const Divider(
                              indent: 16, endIndent: 16, height: 0.5),
                          itemBuilder: (ctx, i) {
                            final issue = _issues[i];
                            final state = _states[issue.state];
                            return IssueRow(
                              issue: issue,
                              state: state,
                              allLabels: _labels,
                              allMembers: _members,
                              onTap: () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          IssueDetailScreen(
                                        workspaceSlug:
                                            widget.workspaceSlug,
                                        projectId: widget.projectId,
                                        issueId: issue.id,
                                        states: _states,
                                      ),
                                    ));
                                _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}
