import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/member.dart';
import '../../services/issue_service.dart';
import 'issue_detail_screen.dart';

class SpreadsheetView extends StatelessWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;
  final List<Issue> issues;
  final Map<String, IssueState> states;
  final List<Member> allMembers;
  final VoidCallback onRefresh;

  const SpreadsheetView({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
    required this.issues,
    required this.states,
    required this.onRefresh,
    this.allMembers = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.colorScheme.outlineVariant;

    return Column(
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 0.5)),
            color: theme.colorScheme.surface,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HeaderCell(label: 'ID', width: 80),
                _HeaderCell(label: 'Title', width: 200),
                _HeaderCell(label: 'State', width: 120),
                _HeaderCell(label: 'Priority', width: 100),
                _HeaderCell(label: 'Assignee', width: 120),
                _HeaderCell(label: 'Due Date', width: 110),
              ],
            ),
          ),
        ),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: issues.length,
            itemBuilder: (ctx, i) {
              final issue = issues[i];
              final state = states[issue.state];
              final assigneeNames = allMembers
                  .where((m) => issue.assignees.contains(m.id))
                  .map((m) => m.displayName)
                  .join(', ');

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: border, width: 0.5)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // ID
                      _DataCell(
                        width: 80,
                        child: Text(
                          '$projectIdentifier-${issue.sequenceId}',
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ),
                      // Title
                      _DataCell(
                        width: 200,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IssueDetailScreen(
                                  workspaceSlug: workspaceSlug,
                                  projectId: projectId,
                                  issueId: issue.id,
                                  states: states,
                                ),
                              ),
                            );
                            onRefresh();
                          },
                          child: Text(
                            issue.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      // State
                      _DataCell(
                        width: 120,
                        // The cell text is just the state name, which repeats
                        // in every row; the label pins it to one issue.
                        child: Semantics(
                          label: 'Change state of '
                              '$projectIdentifier-${issue.sequenceId}',
                          button: true,
                          container: true,
                          child: InkWell(
                            onTap: () => _showStatePicker(context, issue),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PlaneTheme.stateIcon(
                                      state?.group ?? 'backlog'),
                                  size: 14,
                                  color: PlaneTheme.stateGroupColor(context, state?.group ?? 'backlog'),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    state?.name ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Priority
                      _DataCell(
                        width: 100,
                        child: Semantics(
                          label: 'Change priority of '
                              '$projectIdentifier-${issue.sequenceId}',
                          button: true,
                          container: true,
                          child: InkWell(
                            onTap: () =>
                                _showPriorityPicker(context, issue),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PlaneTheme.priorityIcon(issue.priority),
                                  size: 14,
                                  color: PlaneTheme.priorityColor(context, issue.priority),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  issue.priority[0].toUpperCase() +
                                      issue.priority.substring(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Assignee
                      _DataCell(
                        width: 120,
                        child: Text(
                          assigneeNames.isEmpty
                              ? 'Unassigned'
                              : assigneeNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: assigneeNames.isEmpty
                                ? secondary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Due Date
                      _DataCell(
                        width: 110,
                        child: Text(
                          issue.targetDate ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: issue.isOverdue
                                ? PlaneTheme.urgent
                                : secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showStatePicker(BuildContext context, Issue issue) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: states.values
              .map((s) => ListTile(
                    leading: Icon(PlaneTheme.stateIcon(s.group),
                        color: PlaneTheme.stateGroupColor(context, s.group),
                        size: 18),
                    title: Text(s.name,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await IssueService.updateIssue(
                          workspaceSlug, projectId, issue.id,
                          {'state': s.id});
                      onRefresh();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showPriorityPicker(BuildContext context, Issue issue) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['urgent', 'high', 'medium', 'low', 'none']
              .map((p) => ListTile(
                    leading: Icon(PlaneTheme.priorityIcon(p),
                        color: PlaneTheme.priorityColor(context, p), size: 18),
                    title: Text(p[0].toUpperCase() + p.substring(1),
                        style: const TextStyle(fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await IssueService.updateIssue(
                          workspaceSlug, projectId, issue.id,
                          {'priority': p});
                      onRefresh();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final double width;
  final Widget child;
  const _DataCell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // Rows open the issue and the state/priority cells open pickers, so a
      // row is never shorter than a fingertip.
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: child,
    );
  }
}
