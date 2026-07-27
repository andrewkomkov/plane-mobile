import 'package:flutter/material.dart';
import '../config/m3e/shapes.dart';
import '../config/m3e/typography.dart';

/// Universal section/group header used across all list screens.
/// Uppercase overline label + count badge pill.
class SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final Color? color;

  /// The section's own control, pinned to the far end of the header row.
  ///
  /// Project settings wrapped this widget in a `Row` with an `Expanded` to get
  /// one, which works only because the header's right inset happens to leave
  /// room; anything wider pushed the label out of its own padding. Declared
  /// here, the label keeps the `Flexible` it already has and the control keeps
  /// the header's 20dp right inset.
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.label,
    this.count,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 8),
      child: Row(
        children: [
          // A short colour bar carries the state-group hue, so the label
          // itself can stay neutral and legible at 11px.
          if (color != null) ...[
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: effectiveColor,
                borderRadius: BorderRadius.circular(M3EShape.full),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Label and count take the space [trailing] does not, rather than
          // splitting it with it: a Flexible label beside a Spacer would
          // ellipsize at half the header even when the control is a 40dp
          // button.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // The hue stays on the bar above, which is a non-text
                    // element and only owes 3:1. As 11px text these same hues
                    // fall to 1.92:1.
                    style: M3EType.overline(theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(M3EShape.full),
                    ),
                    child: Text(
                      '$count',
                      // Emphasized: the pill is small and low-contrast, and the
                      // design asked for a heavier cut than labelSmall's w500.
                      style: M3EType.emphasized(theme.textTheme.labelSmall!)
                          .copyWith(color: theme.colorScheme.onSurfaceVariant),
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
