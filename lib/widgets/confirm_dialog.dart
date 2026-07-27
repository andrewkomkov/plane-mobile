import 'package:flutter/material.dart';

/// Confirm something that cannot be undone.
///
/// The app has 31 hand-rolled `AlertDialog`s and they disagree about the one
/// thing a confirmation dialog exists to communicate. Seven of them style the
/// destructive button exactly like "Cancel" — plain, unadorned, same weight,
/// same colour — for actions that delete a page, a view or a label. Two more
/// reach for a bare `TextStyle(color: error)`, which discards
/// `textButtonTheme`'s `labelLarge` + `w600` and renders the dangerous button
/// at a *lighter* weight than the safe one beside it.
///
/// This is the one shape. `confirmMemberAction` in `member_row.dart` had it
/// right and had six call sites; this is that function with the word "member"
/// taken out of it, and that one now forwards here.
///
/// The confirming action is last, in the error role, at the button theme's own
/// weight. Cancel is first and quiet, and is what a dismissed dialog returns —
/// a barrier tap or a back gesture is never a confirmation.
///
/// No local `shape:`: `dialogTheme` carries the expressive corner and the
/// hairline, and re-specifying it here is how two dialogs end up disagreeing
/// after somebody changes the token.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) =>
    _confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: true,
    );

/// Confirm something that is reversible, or that undoes an archive.
///
/// The same shape, without the error role. Three screens hand-rolled a restore
/// dialog rather than call [confirmDestructive], and they were right to:
/// painting "Restore" in the colour the app uses for delete says the action is
/// dangerous when it is the one that puts things back. This is that dialog,
/// declared once, so restoring a cycle, a module and a page stop being three
/// separate `AlertDialog`s that happen to agree today.
///
/// The confirming action keeps its place — last, and at the button theme's own
/// weight — so muscle memory carries between the two variants. Only the colour
/// differs, which is the one thing the two are meant to say differently.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) =>
    _confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: false,
    );

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  required bool destructive,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            // Null, not a primary colour: the non-destructive variant should
            // inherit whatever `textButtonTheme` says a button looks like, the
            // same as Cancel beside it.
            style: destructive
                ? TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
