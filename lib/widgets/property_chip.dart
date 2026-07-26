import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';
import '../config/theme.dart';

/// Read-only property display (state, priority, assignee, due date).
///
/// Distinct from [M3EChip]: the icon keeps its own semantic colour — priority
/// red, state green — while the label stays neutral, so a row of these reads as
/// data rather than as a row of selectable filters.
class PropertyChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const PropertyChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(M3EShape.small),
        // A chip's outline is what makes it read as a chip, so it takes the
        // control-boundary role rather than the decorative divider one.
        border: Border.all(color: scheme.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: PlaneTheme.iconSmall, color: iconColor),
          const SizedBox(width: 6),
          // Flexible because a chip is now also used inside a fixed-width
          // table cell, where a long state name would otherwise overflow
          // rather than truncate.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );

    return M3EPressable(
      pressedScale: onTap == null ? 1.0 : 0.94,
      onTap: onTap,
      // The pill is ~28dp tall by design — it has to sit in a property row
      // without dominating it. When it is tappable the hit area is padded out
      // to 48dp instead, so the target is a fingertip even though the ink is
      // not.
      //
      // `widthFactor` is what keeps that vertical-only. A bare Center takes the
      // full width it is offered, which in the Wrap these sit in makes every
      // pill a full-width row — six chips stacked down the screen instead of
      // flowing across it.
      child: onTap == null
          ? chip
          : SizedBox(
              height: 48,
              child: Center(widthFactor: 1.0, child: chip),
            ),
    );
  }
}
