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
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
