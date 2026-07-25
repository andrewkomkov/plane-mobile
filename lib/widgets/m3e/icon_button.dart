import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';

/// Material 3 Expressive icon button sizes.
///
/// M3E replaced "one icon button" with a size ramp, because a 24dp glyph in a
/// toolbar and the same glyph as a screen's primary action are not the same
/// control. Each step fixes both the visible container and the icon inside it;
/// the touch target is always at least 48dp regardless, which is the part that
/// most hand-rolled icon buttons get wrong.
enum M3EIconButtonSize {
  /// Dense rows — markdown toolbars, table headers.
  extraSmall(container: 32, icon: 18),

  /// Inline actions inside cards and list rows.
  small(container: 40, icon: 20),

  /// The default: app bar actions, toolbars.
  medium(container: 48, icon: 22),

  /// A screen's primary action.
  large(container: 56, icon: 26);

  const M3EIconButtonSize({required this.container, required this.icon});

  final double container;
  final double icon;
}

/// How the container is filled.
enum M3EIconButtonStyle {
  /// No fill until pressed. The default — a row of these stays quiet.
  standard,

  /// Tonal fill, for the one action on screen that should be found first.
  filled,

  /// Hairline outline, for actions that need presence without weight.
  outlined,
}

/// Material 3 Expressive icon button.
///
/// The single source of truth for every icon-only control in the app, so that
/// circles are the same diameter, icons are optically centred in them, and
/// nothing ends up with a touch target smaller than a fingertip.
///
/// A [tooltip] is required rather than optional: an icon-only control with no
/// label is unreachable for screen readers and for the adb driver in
/// `tool/adb_drive.py`, and making it required is what stops that regressing.
class M3EIconButton extends StatelessWidget {
  final IconData icon;

  /// Doubles as the accessibility label. Describe the action, not the glyph.
  final String tooltip;

  final VoidCallback? onPressed;
  final M3EIconButtonSize size;
  final M3EIconButtonStyle style;

  /// Overrides the icon colour — for destructive actions or semantic state.
  final Color? color;

  /// Selected toggles square off their corners as well as filling, so state
  /// survives without relying on colour alone.
  final bool? selected;

  const M3EIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = M3EIconButtonSize.medium,
    this.style = M3EIconButtonStyle.standard,
    this.color,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected ?? false;
    final enabled = onPressed != null;

    // Both ends of the selection transition, rather than the resolved value:
    // the springs below interpolate between them, so the fill and the corner
    // travel instead of switching.
    final Color restBackground;
    final Color selectedBackground;
    final Color restForeground;
    final Color selectedForeground;
    switch (style) {
      case M3EIconButtonStyle.filled:
        // A filled button is already filled; selection has nothing to say.
        restBackground = selectedBackground = scheme.primaryContainer;
        restForeground = selectedForeground = scheme.onPrimaryContainer;
      case M3EIconButtonStyle.outlined:
      case M3EIconButtonStyle.standard:
        restBackground = Colors.transparent;
        selectedBackground = scheme.primary.withValues(alpha: 0.14);
        restForeground = scheme.onSurfaceVariant;
        selectedForeground = scheme.primary;
    }

    // Corner morph: round at rest, squarer when selected.
    final restCorner = size.container / 2;
    const selectedCorner = M3EShape.medium;

    return M3EPressable(
      pressedScale: 0.86,
      onTap: onPressed,
      semanticLabel: tooltip,
      selected: selected,
      child: SizedBox(
        // Touch target stays at the 48dp minimum even when the visible circle
        // is smaller, so dense toolbars are still usable with a thumb.
        width: size.container < 48 ? 48 : size.container,
        height: size.container < 48 ? 48 : size.container,
        child: Center(
          // Shape rides a spatial spring and is allowed to overshoot; the fill
          // rides a critically damped effects spring, because a colour that
          // overshoots reads as a glitch. A single duration curve could
          // express neither.
          child: M3ESpringBuilder(
            value: isSelected ? 1 : 0,
            spring: M3EMotion.fastSpatial,
            builder: (context, shapeT, _) => M3ESpringBuilder(
              value: isSelected ? 1 : 0,
              spring: M3EMotion.defaultEffects,
              builder: (context, tintT, __) {
                final t = tintT.clamp(0.0, 1.0);
                final background =
                    Color.lerp(restBackground, selectedBackground, t)!;
                final resolved = color ??
                    Color.lerp(restForeground, selectedForeground, t)!;
                final corner = restCorner +
                    (selectedCorner - restCorner) * shapeT.clamp(0.0, 1.0);

                return Container(
                  width: size.container,
                  height: size.container,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(corner),
                    border: style == M3EIconButtonStyle.outlined
                        ? Border.all(color: scheme.outline, width: 0.8)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: size.icon,
                    color: enabled
                        ? resolved
                        : resolved.withValues(alpha: 0.38),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
