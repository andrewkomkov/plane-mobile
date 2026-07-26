import 'package:flutter/material.dart';

import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../config/theme.dart';
import '../../models/intake_issue.dart';
import '../../services/intake_service.dart';
import '../../utils/api_error.dart';
import 'intake_duplicate_picker.dart';
import 'intake_status.dart';

/// What a maintainer can do to an entry sitting in Intake.
///
/// This is the server's action set, not an invention. `IntakeIssueViewSet`
/// exposes exactly one write for triage — a PATCH that sets `status`, plus
/// `snoozed_till` or `duplicate_to` where the status needs one — and Plane's
/// own client sends the four payloads below and no others
/// (`web/core/store/inbox/inbox-issue.store.ts`):
///
/// | Action | Payload |
/// |---|---|
/// | Accept | `{status: 1}` |
/// | Decline | `{status: -1}` |
/// | Snooze | `{status: 0, snoozed_till: <ISO>}` |
/// | Un-snooze | `{status: -2, snoozed_till: null}` |
/// | Duplicate | `{status: 2, duplicate_to: <work item id>}` |
///
/// Two things the server does **not** have, and which are therefore not
/// offered here however natural they look:
///
/// - **A decline reason.** `intake_issues` has no such column and the
///   serialiser has no such field. Plane's decline dialog is a bare "are you
///   sure"; anything typed into a reason box here would be discarded silently.
/// - **A way back.** Accept, decline and duplicate are terminal in Plane's own
///   UI, which offers nothing but "open the work item" once an entry is
///   closed. The status column would take another value, but accepting
///   something already declined does not undo what the decline did to the work
///   item, so the app does not pretend it is an undo.
enum IntakeAction { accept, decline, snooze, unsnooze, duplicate }

/// Runs [action] against [entry], asking for whatever the action needs first.
///
/// Returns true when the queue should reload — which is not the same as "the
/// action succeeded", because a status the server declined to change still
/// means the caller's copy is stale.
Future<bool> runIntakeAction(
  BuildContext context, {
  required String workspaceSlug,
  required String projectId,
  required String projectIdentifier,
  required IntakeIssue entry,
  required IntakeAction action,
}) async {
  final label = intakeEntryLabel(entry, projectIdentifier);

  int status;
  DateTime? snoozedTill;
  var clearSnooze = false;
  String? duplicateTo;

  switch (action) {
    case IntakeAction.accept:
      final ok = await _confirm(
        context,
        title: 'Accept $label?',
        // Naming the state change matters: accepting is not just a label on
        // the queue entry, it moves the work item out of Triage and into the
        // project's default state, where everyone else will see it.
        body: 'It leaves Triage for the project’s default state and '
            'becomes normal work.',
        confirmLabel: 'Accept',
      );
      if (!ok) return false;
      status = IntakeStatus.accepted;

    case IntakeAction.decline:
      final ok = await _confirm(
        context,
        title: 'Decline $label?',
        body: 'It leaves the open queue. The work item itself stays in '
            'Triage, and there is no way to take this back.',
        confirmLabel: 'Decline',
        destructive: true,
      );
      if (!ok) return false;
      status = IntakeStatus.declined;

    case IntakeAction.snooze:
      final date = await _pickSnoozeDate(context, entry.snoozedTill);
      if (date == null) return false;
      status = IntakeStatus.snoozed;
      snoozedTill = date;

    case IntakeAction.unsnooze:
      status = IntakeStatus.pending;
      clearSnooze = true;

    case IntakeAction.duplicate:
      final candidate = await Navigator.push<IntakeDuplicateCandidate>(
        context,
        MaterialPageRoute(
          builder: (_) => IntakeDuplicatePicker(
            workspaceSlug: workspaceSlug,
            projectId: projectId,
            excludeIssueId: entry.issueId,
          ),
        ),
      );
      if (candidate == null) return false;
      status = IntakeStatus.duplicate;
      duplicateTo = candidate.id;
  }

  try {
    final result = await IntakeService.triage(
      workspaceSlug,
      projectId,
      // The work item id, not the intake row id — every intake detail handler
      // resolves its path parameter with `issue_id=pk`.
      entry.issueId,
      status: status,
      snoozedTill: snoozedTill,
      clearSnooze: clearSnooze,
      duplicateTo: duplicateTo,
    );
    if (!context.mounted) return true;

    if (result.applied) {
      _say(context, '$label ${_pastTense(action)}');
    } else {
      // The write returned 200 and changed nothing. This is the creator path
      // through `partial_update`: it lets the author of a work item in
      // regardless of role, then applies only the issue half of the payload
      // unless the caller is a project or workspace admin. Reading the status
      // back off the response is the only way to tell.
      _say(
        context,
        'Only a project admin can triage intake items. $label is unchanged.',
        error: true,
      );
    }
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    _say(context, describeApiError(e, fallback: 'Could not update $label'),
        error: true);
    return false;
  }
}

String _pastTense(IntakeAction action) {
  switch (action) {
    case IntakeAction.accept:
      return 'accepted';
    case IntakeAction.decline:
      return 'declined';
    case IntakeAction.snooze:
      return 'snoozed';
    case IntakeAction.unsnooze:
      return 'back in the queue';
    case IntakeAction.duplicate:
      return 'marked duplicate';
  }
}

void _say(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.errorContainer : null,
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for the day an entry should come back.
///
/// The first selectable day is tomorrow, matching Plane's own snooze calendar,
/// which disables everything before today. Snoozing until a moment that has
/// already passed would produce an entry that is snoozed and overdue at once.
Future<DateTime?> _pickSnoozeDate(
    BuildContext context, DateTime? current) async {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final initial = (current != null && current.isAfter(tomorrow))
      ? current.toLocal()
      : tomorrow;

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: tomorrow,
    lastDate: DateTime(now.year + 5),
    helpText: 'Snooze until',
    confirmText: 'Snooze',
  );
}

/// The triage sheet: every action an entry currently admits.
///
/// Only open entries get one. Plane enables accept / decline / snooze /
/// duplicate for pending and snoozed entries only, and this mirrors that
/// rather than offering buttons the server would refuse or, worse, accept
/// without effect.
Future<bool> showIntakeActionSheet(
  BuildContext context, {
  required String workspaceSlug,
  required String projectId,
  required String projectIdentifier,
  required IntakeIssue entry,
}) async {
  if (!entry.isOpen) return false;

  final label = intakeEntryLabel(entry, projectIdentifier);
  final snoozed = entry.status == IntakeStatus.snoozed;

  final chosen = await showModalBottomSheet<IntakeAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(M3EShape.extraLargeIncreased),
          ),
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Text(
                    'Triage $label',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  label: 'Accept',
                  detail: 'Move it out of Triage into the project',
                  color: PlaneTheme.stateGroupColor(ctx, 'completed'),
                  onTap: () => Navigator.pop(ctx, IntakeAction.accept),
                ),
                if (snoozed)
                  _ActionTile(
                    icon: Icons.alarm_on_outlined,
                    label: 'Un-snooze',
                    detail: 'Put it back in the pending queue now',
                    onTap: () => Navigator.pop(ctx, IntakeAction.unsnooze),
                  )
                else
                  _ActionTile(
                    icon: Icons.snooze,
                    label: 'Snooze',
                    detail: 'Hide it until a date you pick',
                    onTap: () => Navigator.pop(ctx, IntakeAction.snooze),
                  ),
                _ActionTile(
                  icon: Icons.copy_all_outlined,
                  label: 'Mark duplicate',
                  detail: 'Point it at the work item it repeats',
                  onTap: () => Navigator.pop(ctx, IntakeAction.duplicate),
                ),
                _ActionTile(
                  icon: Icons.cancel_outlined,
                  label: 'Decline',
                  detail: 'Reject it. This cannot be undone',
                  color: scheme.error,
                  onTap: () => Navigator.pop(ctx, IntakeAction.decline),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (chosen == null || !context.mounted) return false;
  return runIntakeAction(
    context,
    workspaceSlug: workspaceSlug,
    projectId: projectId,
    projectIdentifier: projectIdentifier,
    entry: entry,
    action: chosen,
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;

    return M3EPressable(
      pressedScale: 0.97,
      onTap: onTap,
      // The visible text is two strings in two roles; without this the node
      // announces neither in a useful order, and `tool/adb_drive.py` locates
      // the tile by exactly this name.
      semanticLabel: '$label. $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(M3EShape.large),
        ),
        child: Row(
          children: [
            Icon(icon, size: PlaneTheme.iconLarge, color: tint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          theme.textTheme.titleMedium?.copyWith(color: tint)),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
