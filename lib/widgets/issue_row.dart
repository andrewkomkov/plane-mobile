import 'package:flutter/material.dart';
import 'label_pill.dart';
import '../config/theme.dart';
import '../models/issue.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../models/state.dart';
import 'plane_row.dart';

/// An issue, as [PlaneRow].
///
/// This is the mapping layer and nothing else: it decides which issue property
/// lands in which slot and how the row names itself, and then hands over. It is
/// the only place that mapping is written down, which is the point — every
/// screen that lists issues (project list, my issues, inbox, saved views,
/// calendar, board, cycle and module detail) goes through it, so an issue looks
/// the same in all of them and gains a new property in all of them at once.
///
/// The `show*` flags exist because the display-options sheet lets a user turn
/// row properties on and off. They are not variants — a hidden property is
/// absent from the label too, so what the row announces always matches what it
/// draws.
class IssueRow extends StatelessWidget {
  final Issue issue;
  final IssueState? state;

  /// Project identifier, so the row can render `PLM-123`.
  final String? identifier;

  /// Second line under the title — the inbox puts the activity text here.
  final String? subtitle;

  /// End of the subtitle line: the inbox's "3h ago".
  final String? timeAgo;

  /// Whether to draw the identifier. Defaults to "when there is one", which is
  /// what every screen except the display-options-driven lists wants.
  final bool? showId;

  final bool showProject;
  final bool showAssignee;
  final bool showDueDate;
  final bool showPriority;
  final bool showState;
  final bool showLabels;
  final bool showSubIssues;

  /// An unread notification: the one row in the inbox that must dominate.
  final bool unread;

  /// Row lifted above its neighbours for a reason other than being unread —
  /// the board card currently under the finger.
  final bool highlighted;

  /// Whether this row is picked for a bulk action, or null when the list is
  /// not selecting at all. Null and false are different: false draws the
  /// unpicked half of a selection, which on a list nobody is selecting would
  /// be a mark with no meaning.
  final bool? selected;

  final int maxTitleLines;
  final PlaneRowDensity density;

  /// Extra clauses appended to the accessibility label, for context the row
  /// itself does not draw — the board card uses it to say which column it is
  /// in and that it can be dragged there from.
  final List<String> semanticExtras;

  final VoidCallback? onTap;

  /// Forwarded to [PlaneRow], which declares it on the row's own semantics
  /// node. The notification feed used to wrap this widget in a
  /// `GestureDetector` for the same thing — a nested gesture inside a labelled
  /// control, which is the pattern that silently drops the action for
  /// assistive tech.
  final VoidCallback? onLongPress;

  /// Names what [onLongPress] does. The cycle and module lists set it, because
  /// there the long-press is the only route to removing an issue that a
  /// screen-reader user has — the swipe leaves no node behind and there is no
  /// longer a button in the row.
  final String? longPressHint;

  final List<Label> allLabels;
  final List<Member> allMembers;

  /// A control at the right edge of the row, inside the card — the cycle and
  /// module screens put "remove from this cycle" here.
  ///
  /// Both screens used to hang that button in a `Row` *beside* the card,
  /// because this pass-through did not exist; the icon then floated in the
  /// gutter, outside the surface it acted on, and the card was narrower than
  /// every other list's. [PlaneRow.trailing] is the slot that was already
  /// built for it, and the one place in the row that keeps its own semantics
  /// node, so the button stays reachable from a screen reader and from
  /// `adb_drive.py`.
  final Widget? trailing;

  const IssueRow({
    super.key,
    required this.issue,
    this.state,
    this.identifier,
    this.subtitle,
    this.timeAgo,
    this.showId,
    this.showProject = false,
    this.showAssignee = false,
    this.showDueDate = false,
    this.showPriority = true,
    this.showState = true,
    this.showLabels = false,
    this.showSubIssues = false,
    this.unread = false,
    this.highlighted = false,
    this.selected,
    this.maxTitleLines = 1,
    this.density = PlaneRowDensity.standard,
    this.semanticExtras = const [],
    this.onTap,
    this.onLongPress,
    this.longPressHint,
    this.allLabels = const [],
    this.allMembers = const [],
    this.trailing,
  });

  bool get _showId => showId ?? (identifier != null);

  /// Label the row reports to accessibility and to `adb shell uiautomator`.
  ///
  /// External automation locates a row by its issue identifier (e.g. "AFS-415")
  /// with a substring match, so the identifier goes first and a human listener
  /// still gets the name straight after.
  ///
  /// The label has to carry the row's properties too. [PlaneRow] hands it to
  /// `M3EPressable`, which *replaces* the subtree's semantics with it, so the
  /// state icon, priority, labels and avatars are erased from the tree — a
  /// screen-reader user would otherwise get none of what a sighted user reads
  /// at a glance.
  String _semanticLabel(List<Member> members, List<Label> labels) {
    final parts = <String>[
      if (identifier != null) '$identifier-${issue.sequenceId}',
      issue.name,
      if (showState && state != null) 'state ${state!.name}',
      if (showPriority && issue.priority != 'none')
        'priority ${issue.priority}',
      if (showLabels && labels.isNotEmpty)
        'labels ${labels.take(3).map((l) => l.name).join(', ')}',
      if (showAssignee && members.isNotEmpty)
        'assigned to ${members.take(3).map((m) => m.displayName).join(', ')}',
      if (showSubIssues && issue.subIssuesCount > 0)
        '${issue.subIssuesCount} sub-issues',
      if (showDueDate && issue.isOverdue) 'overdue',
      if (unread) 'unread',
      ...semanticExtras,
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final issueLabels =
        allLabels.where((l) => issue.labels.contains(l.id)).toList();
    final issueMembers =
        allMembers.where((m) => issue.assignees.contains(m.id)).toList();

    return PlaneRow(
      density: density,
      selected: selected,
      icon: showState ? PlaneTheme.stateIcon(state?.group ?? 'backlog') : null,
      iconColor: PlaneTheme.stateGroupColor(context, state?.group ?? 'backlog'),
      identifier: _showId && identifier != null
          ? '$identifier-${issue.sequenceId}'
          : null,
      badges: [
        if (showPriority)
          Icon(
            PlaneTheme.priorityIcon(issue.priority),
            size: PlaneTheme.iconSmall,
            color: PlaneTheme.priorityColor(context, issue.priority),
          ),
      ],
      title: issue.name,
      titleMaxLines: maxTitleLines,
      emphasizeTitle: unread,
      subtitle: subtitle,
      subtitleTrailing: timeAgo,
      chips: [
        if (showLabels)
          for (final label in issueLabels.take(3))
            LabelPill(name: label.name, hex: label.color, dense: true),
      ],
      metadata: [
        if (showSubIssues && issue.subIssuesCount > 0)
          PlaneRowMeta(
            icon: Icons.subdirectory_arrow_right,
            text: '${issue.subIssuesCount}',
          ),
        if (showDueDate && issue.isOverdue)
          PlaneRowMeta(
            icon: Icons.schedule,
            // Overdue is the one indicator whose colour is the message.
            color: PlaneTheme.priorityColor(context, 'urgent'),
          ),
        if (showDueDate && issue.targetDate != null && !issue.isOverdue)
          const PlaneRowMeta(icon: Icons.calendar_today),
        if (showProject && issue.project != null)
          const PlaneRowMeta(icon: Icons.folder_outlined),
        if (showAssignee && issueMembers.isEmpty && issue.assignees.isNotEmpty)
          const PlaneRowMeta(icon: Icons.person),
        // No project identifier to build `PLM-123` from, but the sequence
        // number is still the thing a user quotes.
        if (_showId && identifier == null)
          _SequenceId(sequenceId: issue.sequenceId),
      ],
      avatars: [
        if (showAssignee)
          for (final member in issueMembers)
            PlaneAvatar(name: member.displayName, imageUrl: member.avatar),
      ],
      trailing: trailing,
      highlighted: unread || highlighted,
      semanticLabel: _semanticLabel(issueMembers, issueLabels),
      onTap: onTap,
      onLongPress: onLongPress,
      longPressHint: longPressHint,
    );
  }
}

class _SequenceId extends StatelessWidget {
  final int sequenceId;
  const _SequenceId({required this.sequenceId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text('$sequenceId', style: PlaneRow.identifierStyle(theme));
  }
}

/// A label as a pill.
///
/// A label's colour is whatever hex the server holds, so it cannot be trusted
/// as a text colour — a dark one vanishes on the dark theme, a pale one on the
/// light. It carries in the fill and the dot instead, and the name stays on a
/// role, which is what the detail screen already does.
