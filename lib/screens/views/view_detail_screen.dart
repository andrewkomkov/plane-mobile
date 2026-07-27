import 'package:flutter/material.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../utils/say.dart';
import '../../utils/api_error.dart';
import '../../services/view_service.dart';
import '../../widgets/m3e/app_bar.dart';
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
  ConsumerState<ViewDetailScreen> createState() => _ViewDetailScreenState();
}

class _ViewDetailScreenState extends ConsumerState<ViewDetailScreen> {
  List<Issue> _issues = [];
  Map<String, IssueState> _states = {};
  List<Label> _labels = [];
  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  /// The view's name, which this screen can now change.
  late String _name = widget.view.name;

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
              .where((i) => i.assignees.any((a) => assigneeIds.contains(a)))
              .toList();
        }
      }
      if (qd.containsKey('label') && qd['label'] is List) {
        final labelIds = (qd['label'] as List).map((e) => e.toString()).toSet();
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

  /// The same three-action surface the cycle and module detail screens carry.
  ///
  /// A view could be deleted from its row in the list and from nowhere else,
  /// and could not be renamed anywhere at all — the one detail screen in the
  /// app whose app bar had no actions on it.
  Future<void> _showMoreMenu() async {
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: _name,
      items: const [
        BottomSheetPickerItem(
            value: 'rename', label: 'Rename view', icon: Icons.edit_outlined),
        BottomSheetPickerItem(
          value: 'delete',
          label: 'Delete view',
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (chosen == 'rename') await _rename();
    if (chosen == 'delete') await _delete();
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename view'),
        content: M3ETextField(
          label: 'Name',
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == _name) return;
    try {
      await ViewService.updateView(widget.workspaceSlug, widget.projectId,
          widget.view.id, {'name': name});
      if (mounted) {
        setState(() => _name = name);
        say(context, 'View renamed');
      }
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not rename the view'));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete view',
      message: 'Delete "$_name"? The filters it saves are lost.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ViewService.deleteView(
          widget.workspaceSlug, widget.projectId, widget.view.id);
      // The list screen reloads on every return from here, so popping is what
      // makes the row disappear.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not delete the view'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: _name,
        actions: [
          M3EAppBarAction(
            icon: Icons.more_horiz,
            tooltip: 'View actions',
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load issues', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _issues.isEmpty
                      ? const ScrollableEmptyState(
                          message: 'No issues match this view',
                          icon: Icons.view_list_outlined,
                        )
                      // No separators: the rows are cards with a gap between
                      // them, and a divider inside that gap read as a second,
                      // competing grouping.
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _issues.length,
                          itemBuilder: (ctx, i) {
                            final issue = _issues[i];
                            final state = _states[issue.state];
                            return IssueRow(
                              issue: issue,
                              state: state,
                              showLabels: true,
                              showSubIssues: true,
                              showAssignee: true,
                              showDueDate: true,
                              allLabels: _labels,
                              allMembers: _members,
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
