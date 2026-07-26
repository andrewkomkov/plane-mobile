import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/member.dart';
import '../../services/issue_service.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/property_chip.dart';
import 'issue_detail_screen.dart';

/// Column widths, stated once.
///
/// The header and every data row read from here. When each row owned its own
/// numbers the two could drift apart silently, and a table whose header does
/// not line up with its body is worse than no header.
class _Col {
  static const double id = 80;
  static const double title = 200;
  static const double state = 120;
  static const double priority = 100;
  static const double assignee = 120;
  static const double due = 110;

  static const double total = id + title + state + priority + assignee + due;
}

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
    final border = theme.colorScheme.outlineVariant;

    if (issues.isEmpty) {
      // Previously the empty table drew its header row over blank space, which
      // reads as a table that failed to load rather than a project with no
      // work in it.
      return const ScrollableEmptyState(
        message: 'No work items',
        icon: Icons.table_rows_outlined,
        subtitle: 'Work items in this project appear here as a table',
      );
    }

    // One horizontal scroll for the whole table.
    //
    // The header and each data row used to carry a `SingleChildScrollView` of
    // their own, so dragging one row sideways moved that row and nothing else:
    // the header stayed put and every other row stayed put, and the columns
    // stopped meaning anything. A single scrollable of a fixed width, with the
    // vertical list inside it, is what makes this a table — the header stays
    // pinned above the rows vertically and travels with them horizontally.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _Col.total,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 0.5)),
                color: theme.colorScheme.surface,
              ),
              child: const Row(
                children: [
                  _HeaderCell(label: 'ID', width: _Col.id),
                  _HeaderCell(label: 'Title', width: _Col.title),
                  _HeaderCell(label: 'State', width: _Col.state),
                  _HeaderCell(label: 'Priority', width: _Col.priority),
                  _HeaderCell(label: 'Assignee', width: _Col.assignee),
                  _HeaderCell(label: 'Due Date', width: _Col.due),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: issues.length,
                itemBuilder: (ctx, i) => _row(ctx, issues[i], border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Issue issue, Color border) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final state = states[issue.state];
    final assigneeNames = allMembers
        .where((m) => issue.assignees.contains(m.id))
        .map((m) => m.displayName)
        .join(', ');
    final identifier = '$projectIdentifier-${issue.sequenceId}';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ID. Same treatment as the identifier a list row draws, because it
          // is the same string in the same product.
          _DataCell(
            width: _Col.id,
            child: Text(identifier, style: PlaneRow.identifierStyle(theme)),
          ),
          // Title. The cell reserves 48dp, so the control that opens the work
          // item fills it — an `InkWell` around the text alone was a 20dp band
          // across the middle. `M3EPressable` rather than ink, because the
          // table is the last surface in this screen still rippling.
          _DataCell(
            width: _Col.title,
            child: M3EPressable(
              // A row is wide; a card's squeeze on it reads as the table
              // moving rather than the cell.
              pressedScale: 0.98,
              semanticLabel: 'Open $identifier, ${issue.name}',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(
                      workspaceSlug: workspaceSlug,
                      projectId: projectId,
                      issueId: issue.id,
                      projectIdentifier: projectIdentifier,
                      states: states,
                    ),
                  ),
                );
                onRefresh();
              },
              child: SizedBox(
                height: kMinInteractiveDimension,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    issue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ),
          // State. A property with an icon in its own colour and a neutral
          // label is a PropertyChip, which is what the module list and the
          // issue detail already use.
          _DataCell(
            width: _Col.state,
            // The chip text is just the state name, which repeats in every
            // row; the label pins it to one work item.
            child: Semantics(
              label: 'State ${state?.name ?? 'Unknown'}, change state of '
                  '$identifier',
              button: true,
              container: true,
              // Excluded, or the state name the chip draws lands on the node
              // beside the label and the cell reports it twice. That means the
              // label has to carry the current value itself, and the chip's
              // own tap has to be re-declared here.
              excludeSemantics: true,
              onTap: () => _showStatePicker(context, issue),
              child: PropertyChip(
                icon: PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                iconColor: PlaneTheme.stateGroupColor(
                    context, state?.group ?? 'backlog'),
                label: state?.name ?? 'Unknown',
                onTap: () => _showStatePicker(context, issue),
              ),
            ),
          ),
          // Priority
          _DataCell(
            width: _Col.priority,
            child: Semantics(
              label: 'Priority ${issue.priority}, change priority of '
                  '$identifier',
              button: true,
              container: true,
              // Same as the state cell beside it.
              excludeSemantics: true,
              onTap: () => _showPriorityPicker(context, issue),
              child: PropertyChip(
                icon: PlaneTheme.priorityIcon(issue.priority),
                iconColor: PlaneTheme.priorityColor(context, issue.priority),
                label: issue.priority[0].toUpperCase() +
                    issue.priority.substring(1),
                onTap: () => _showPriorityPicker(context, issue),
              ),
            ),
          ),
          // Assignee
          _DataCell(
            width: _Col.assignee,
            child: assigneeNames.isEmpty
                ? const _Unset(label: 'Unassigned')
                : Text(
                    assigneeNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
          ),
          // Due Date
          _DataCell(
            width: _Col.due,
            child: (issue.targetDate?.isEmpty ?? true)
                ? const _Unset(label: 'No date')
                : Text(
                    issue.targetDate!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: issue.isOverdue
                          // The raw constant is tuned for the dark surface and
                          // the theme's own comment measures it as failing on
                          // light; the accessor is the way to ask for it.
                          ? PlaneTheme.priorityColor(context, 'urgent')
                          : secondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatePicker(BuildContext context, Issue issue) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: 'State',
      subtitle: '$projectIdentifier-${issue.sequenceId}',
      // The sheet used to show no selection at all, while the same picker on
      // the create screen showed a check.
      selectedValue: issue.state,
      items: states.values
          .map((s) => BottomSheetPickerItem(
                value: s.id,
                label: s.name,
                icon: PlaneTheme.stateIcon(s.group),
                iconColor: PlaneTheme.stateGroupColor(context, s.group),
              ))
          .toList(),
    );
    if (chosen == null || chosen == issue.state) return;
    try {
      await IssueService.updateIssue(
          workspaceSlug, projectId, issue.id, {'state': chosen});
      onRefresh();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to change state: $e')));
    }
  }

  Future<void> _showPriorityPicker(BuildContext context, Issue issue) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await BottomSheetPicker.show<String>(
      context: context,
      title: 'Priority',
      subtitle: '$projectIdentifier-${issue.sequenceId}',
      selectedValue: issue.priority,
      items: ['urgent', 'high', 'medium', 'low', 'none']
          .map((p) => BottomSheetPickerItem(
                value: p,
                label: p[0].toUpperCase() + p.substring(1),
                icon: PlaneTheme.priorityIcon(p),
                iconColor: PlaneTheme.priorityColor(context, p),
              ))
          .toList(),
    );
    if (chosen == null || chosen == issue.priority) return;
    try {
      await IssueService.updateIssue(
          workspaceSlug, projectId, issue.id, {'priority': chosen});
      onRefresh();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Failed to change priority: $e')));
    }
  }
}

/// An empty cell, said out loud.
///
/// "Unassigned" and a real assignee used to differ by text colour alone, at the
/// same size and the same weight — which is no difference at all for a
/// colour-blind user and barely one for anybody else. The italic cut carries it
/// in a second channel.
class _Unset extends StatelessWidget {
  final String label;

  const _Unset({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
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
      // Rows open the work item and the state/priority cells open pickers, so
      // a row is never shorter than a fingertip.
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: child,
    );
  }
}
