import 'package:flutter/material.dart';
import '../config/m3e/shapes.dart';
import '../config/m3e/typography.dart';

/// Universal section/group header used across all list screens.
/// Uppercase overline label + count badge pill.
class SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final Color? color;

  const SectionHeader({
    super.key,
    required this.label,
    this.count,
    this.color,
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
          Flexible(
            child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // The hue stays on the bar above, which is a non-text element and
            // only owes 3:1. As 11px text these same hues fall to 1.92:1.
            style: M3EType.overline(theme.colorScheme.onSurfaceVariant),
          ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
    );
  }
}
