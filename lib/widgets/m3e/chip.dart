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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = accentColor ?? scheme.primary;

    final selectedBackground = accent.withValues(alpha: 0.16);
    // Selected borrows the accent so the outline agrees with the fill; at rest
    // it is the one neutral outline every bordered surface in the app uses.
    final selectedBorder = accent.withValues(alpha: 0.4);

    return M3EPressable(
      pressedScale: 0.94,
      onTap: onTap,
      selected: selected,
      // Shape and colour are separate kinds of change and get separate
      // physics, which is the distinction the whole motion scheme is built on.
      //
      // The outer spring is spatial: the corner morph is the reason this
      // component exists, and it is allowed to overshoot. It used to be fed
      // into an AnimatedContainer, whose own 160ms curve re-animated toward
      // each value the spring produced — a low-pass filter sitting on top of
      // the spring, flattening the exact overshoot being computed.
      child: M3ESpringBuilder(
        value: selected ? 1 : 0,
        spring: M3EMotion.fastSpatial,
        builder: (context, shapeT, _) => M3ESpringBuilder(
          // The inner spring is an effects spring: critically damped, because
          // a tint that sails past its target and comes back reads as a bug.
          value: selected ? 1 : 0,
          spring: M3EMotion.defaultEffects,
          builder: (context, tintT, __) {
            final t = tintT.clamp(0.0, 1.0);
            final background =
                Color.lerp(Colors.transparent, selectedBackground, t)!;
            final foreground =
                Color.lerp(scheme.onSurfaceVariant, accent, t)!;
            final borderColor =
                Color.lerp(scheme.outline, selectedBorder, t)!;

            const rest = M3EShape.largeIncreased;
            final corner =
                rest - (rest - M3EShape.small) * shapeT.clamp(0.0, 1.0);
            return Container(
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
                    style: (dense
                            ? textTheme.labelMedium
                            : textTheme.labelLarge)
                        ?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
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
                        style: textTheme.labelSmall?.copyWith(
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
      ),
    );
  }
}
