import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Tells the user something happened.
///
/// There are seventy-odd `showSnackBar` call sites in this app and, until this
/// existed, every one of them rendered identically: `snackBarTheme` gives
/// `surfaceContainerHighest` and nothing else, so "View saved" and "Failed to
/// restore cycle: DioException…" were the same grey rectangle and a failure
/// was distinguished only by its words. On the light theme that rectangle is
/// 1.13:1 against the scaffold, which is a floating surface a user can miss
/// entirely.
///
/// [say] keeps the themed surface. [sayError] takes the error container pair
/// and an icon, so a failure is a different object on screen, not a different
/// sentence.
void say(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    // A second message replaces the first rather than queueing behind it: a
    // user who taps three rows should see the third answer, not wait for it.
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Tells the user something went wrong.
///
/// The colour is not the only channel — the icon carries it too, because the
/// error container and the default surface are close enough on the light ramp
/// that colour alone is a weak signal, and because a snackbar is exactly the
/// kind of thing a user sees out of the corner of an eye.
void sayError(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: scheme.errorContainer,
      content: Row(
        children: [
          Icon(Icons.error_outline,
              size: PlaneTheme.iconLarge, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    ));
}
