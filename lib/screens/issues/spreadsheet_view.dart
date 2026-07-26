import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/member.dart';
import '../../services/issue_service.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/property_chip.dart';
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
                  border: Border(bottom: BorderSide(color: border, width: 0.5)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // ID. Same treatment as the identifier a list row draws,
                      // because it is the same string in the same product.
                      _DataCell(
                        width: 80,
                        child: Text(
                          '$projectIdentifier-${issue.sequenceId}',
                          style: PlaneRow.identifierStyle(theme),
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
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                      // State. A property with an icon in its own colour and a
                      // neutral label is a PropertyChip, which is what the
                      // module list and the issue detail already use — the
                      // table used to hand-roll the same pairing a size and a
                      // colour off.
                      _DataCell(
                        width: 120,
                        // The chip text is just the state name, which repeats
                        // in every row; the label pins it to one issue.
                        child: Semantics(
                          label: 'Change state of '
                              '$projectIdentifier-${issue.sequenceId}',
                          button: true,
                          container: true,
                          child: PropertyChip(
                            icon:
                                PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                            iconColor: PlaneTheme.stateGroupColor(
                                context, state?.group ?? 'backlog'),
                            label: state?.name ?? 'Unknown',
                            onTap: () => _showStatePicker(context, issue),
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
                          child: PropertyChip(
                            icon: PlaneTheme.priorityIcon(issue.priority),
                            iconColor: PlaneTheme.priorityColor(
                                context, issue.priority),
                            label: issue.priority[0].toUpperCase() +
                                issue.priority.substring(1),
                            onTap: () => _showPriorityPicker(context, issue),
                          ),
                        ),
                      ),
                      // Assignee
                      _DataCell(
                        width: 120,
                        child: Text(
                          assigneeNames.isEmpty ? 'Unassigned' : assigneeNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                issue.isOverdue ? PlaneTheme.urgent : secondary,
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
                    title:
                        Text(s.name, style: Theme.of(ctx).textTheme.bodyMedium),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await IssueService.updateIssue(
                          workspaceSlug, projectId, issue.id, {'state': s.id});
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
                        style: Theme.of(ctx).textTheme.bodyMedium),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await IssueService.updateIssue(
                          workspaceSlug, projectId, issue.id, {'priority': p});
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
        style: theme.textTheme.labelMedium?.copyWith(
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
