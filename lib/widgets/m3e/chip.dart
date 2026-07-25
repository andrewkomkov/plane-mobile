import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';

/// Material 3 Expressive filter/assist chip.
///
/// Selection changes *shape* as well as colour: a selected chip pulls its
/// corners in from the largeIncreased step down to small. That gives the state
/// a second, non-colour channel, which survives both themes and colour-blind
/// users far better than a tint alone.
class M3EChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Overrides the accent for state/priority chips that carry their own colour.
  final Color? accentColor;

  /// Trailing count badge, e.g. the number of active filters.
  final int? count;

  final bool dense;

  const M3EChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.accentColor,
    this.count,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    final background = selected
        ? accent.withValues(alpha: 0.16)
        : Colors.transparent;
    final foreground = selected ? accent : scheme.onSurfaceVariant;
    // Selected borrows the accent so the outline agrees with the fill; at rest
    // it is the one neutral outline every bordered surface in the app uses.
    final borderColor = selected
        ? accent.withValues(alpha: 0.4)
        : scheme.outline;

    return M3EPressable(
      pressedScale: 0.94,
      onTap: onTap,
      selected: selected,
      child: M3ESpringBuilder(
        value: selected ? 1 : 0,
        spring: M3EMotion.fastSpatial,
        builder: (context, t, _) {
          const rest = M3EShape.largeIncreased;
          final corner = rest - (rest - M3EShape.small) * t.clamp(0.0, 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Easing.standard,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 14,
              vertical: dense ? 5 : 7,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(corner),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dense ? 14 : 16, color: foreground),
                  SizedBox(width: dense ? 5 : 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: dense ? 12 : 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(M3EShape.full),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
