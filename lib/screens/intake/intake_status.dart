import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/theme.dart';
import '../../models/intake_issue.dart';

/// How an intake status looks and reads, in one place.
///
/// The queue, the entry screen and the action sheet all have to name the same
/// five statuses, and a triage decision is exactly the kind of thing that must
/// not be one colour in a list and another on the screen it opens.
///
/// Every one of these is drawn from the theme rather than written as a hex:
/// accepted borrows the completed state-group colour, declined the error role,
/// pending the same amber the offline-write badge uses. That keeps the three
/// "this went well / this went badly / this is waiting" signals in the app
/// saying the same thing in the same colour.
class IntakeStatusLook {
  const IntakeStatusLook._();

  static IconData icon(int status) {
    switch (status) {
      case IntakeStatus.pending:
        // Deliberately not an inbox tray. The app's Inbox tab is the
        // notification feed and uses Icons.inbox_outlined; sharing the glyph
        // would merge two unrelated places in a user's head.
        return Icons.fact_check_outlined;
      case IntakeStatus.snoozed:
        return Icons.snooze;
      case IntakeStatus.accepted:
        return Icons.check_circle_outline;
      case IntakeStatus.declined:
        return Icons.cancel_outlined;
      case IntakeStatus.duplicate:
        return Icons.copy_all_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static Color color(BuildContext context, int status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case IntakeStatus.pending:
        return PlaneTheme.pendingColor(context);
      case IntakeStatus.snoozed:
        return scheme.onSurfaceVariant;
      case IntakeStatus.accepted:
        return PlaneTheme.stateGroupColor(context, 'completed');
      case IntakeStatus.declined:
        return scheme.error;
      case IntakeStatus.duplicate:
        return scheme.onSurfaceVariant;
      default:
        return scheme.onSurfaceVariant;
    }
  }
}

/// A date as `12.03.2026`.
///
/// Absolute rather than relative, for the same reason `archivedOnLabel` is: a
/// snooze wake date is a calendar appointment, and "in 23 days" is not
/// something anyone can act on.
String intakeDateLabel(DateTime date) {
  final local = date.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return '$d.$m.${local.year}';
}

/// The status, as a pill. Used on the entry screen, where the status is the
/// headline fact rather than one column of a row.
class IntakeStatusPill extends StatelessWidget {
  final IntakeIssue entry;

  const IntakeStatusPill({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = IntakeStatusLook.color(context, entry.status);
    final text = entry.snoozeExpired ? 'Snooze over' : entry.statusLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IntakeStatusLook.icon(entry.status),
              size: PlaneTheme.iconSmall, color: color),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// How an entry is named everywhere a human or a script has to refer to it.
///
/// `PLM-42` when the project identifier is known. It is not always: a project
/// reached through a route that never loaded one leaves it empty, and a bare
/// sequence number is still something a user can quote.
String intakeEntryLabel(IntakeIssue entry, String projectIdentifier) =>
    projectIdentifier.isEmpty
        ? 'Work item ${entry.issue.sequenceId}'
        : '$projectIdentifier-${entry.issue.sequenceId}';

/// Everything a queue row draws, as one string.
///
/// [PlaneRow] hands its label to `M3EPressable`, which *replaces* the
/// subtree's semantics — so the status icon, the priority glyph and the
/// subtitle are all erased from the accessibility tree unless this says them.
/// `tool/adb_drive.py` finds a row by substring, and the identifier leads for
/// that reason.
String intakeRowSemanticLabel(IntakeIssue entry, String projectIdentifier) {
  final issue = entry.issue;
  return [
    intakeEntryLabel(entry, projectIdentifier),
    issue.name,
    entry.statusLabel.toLowerCase(),
    if (issue.priority != 'none') 'priority ${issue.priority}',
    intakeSubtitle(entry),
  ].join(', ');
}

/// The one-line explanation under an entry's title.
///
/// Says what the status *means for this entry* rather than repeating the
/// status word: a snooze names its wake date, a duplicate names its original
/// when the server expanded it.
String intakeSubtitle(IntakeIssue entry) {
  switch (entry.status) {
    case IntakeStatus.snoozed:
      final till = entry.snoozedTill;
      if (till == null) return 'Snoozed';
      return entry.snoozeExpired
          ? 'Snooze ran out ${intakeDateLabel(till)}'
          : 'Snoozed until ${intakeDateLabel(till)}';
    case IntakeStatus.duplicate:
      final name = entry.duplicateName;
      return name == null ? 'Marked duplicate' : 'Duplicate of $name';
    case IntakeStatus.accepted:
      return 'Accepted into the project';
    case IntakeStatus.declined:
      return 'Declined';
    default:
      return 'Waiting for triage';
  }
}
