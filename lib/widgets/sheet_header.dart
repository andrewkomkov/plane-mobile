import 'package:flutter/material.dart';

/// The title line at the top of a bottom sheet.
///
/// There are 45 hand-rolled sheets in this app and they disagree about this one
/// element: `titleMedium` on six of them, `titleLarge` on two, and no header at
/// all on five. Same gesture, same surface, three different answers to "what am
/// I looking at".
///
/// `titleMedium` is the one that wins, because it is both the majority and the
/// right role — a sheet is a section of the screen it slid out of, not a screen
/// of its own, and `titleLarge` competes with the app bar behind it.
///
/// No drag handle: `bottomSheetTheme` sets `showDragHandle: true`, so the
/// framework has already drawn one, and four sheets in this app currently paint
/// a second one underneath it.
class SheetHeader extends StatelessWidget {
  final String title;

  /// A line under the title — what the choice affects, or how many there are.
  final String? subtitle;

  /// Right-hand action. "Reset", "Clear", "Done" — never the primary action,
  /// which belongs at the bottom where a thumb is.
  final Widget? trailing;

  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Tighter at the top than the bottom because the drag handle already
      // occupies that space.
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
