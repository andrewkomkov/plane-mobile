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
            style: M3EType.overline(
              color != null ? effectiveColor : theme.colorScheme.onSurfaceVariant,
            ),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
