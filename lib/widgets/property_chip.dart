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

  /// Whether the property this chip stands for actually holds a value.
  ///
  /// Null — the default — means the set/unset distinction does not apply here.
  /// A module's status, a cycle's status and a cell in the spreadsheet are
  /// always set and have nothing beside them to be contrasted against, so they
  /// render exactly as every property chip did before this distinction
  /// existed. Those call sites are deliberately left on the default rather
  /// than being restyled.
  ///
  /// The work item's property block is the one place where real values and
  /// empty placeholders sit in the same row, and there an outline alone gave
  /// "Done" and "Assignee" identical weight. True fills the chip and pulls its
  /// corners in; false leaves it hollow at the pill radius. That is two
  /// channels — fill and shape — rather than one, which is what keeps the
  /// distinction readable for a colour-blind user and in both themes.
  final bool? hasValue;

  const PropertyChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
    this.hasValue,
  });

  /// The chip body at a given point between unset (0) and set (1).
  ///
  /// [shapeT] and [tintT] are fed by two different springs, because a corner
  /// travelling and a colour changing are not the same kind of change — see
  /// the build method. [dimLabel] is separate again: a neutral chip is filled
  /// by nothing but still speaks at full strength.
  Widget _body(
    BuildContext context,
    double shapeT,
    double tintT, {
    required bool dimLabel,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = tintT.clamp(0.0, 1.0);

    // The outline stays `outline` in every state. It is the only thing telling
    // a pointer where the control ends, and WCAG 1.4.11 wants 3:1 of that
    // boundary — `outlineVariant` is 1.32:1 on the light background, so
    // dimming the unset chip's border would have traded an accessibility
    // guarantee for the visual difference the fill already provides.
    final background = Color.lerp(
      Colors.transparent,
      scheme.surfaceContainerHigh,
      t,
    )!;
    final labelColor = dimLabel
        ? Color.lerp(scheme.onSurfaceVariant, scheme.onSurface, t)!
        : scheme.onSurface;

    // Same shape pair M3EChip uses for unselected/selected, so a chip that
    // gains a value reads as the same gesture as a filter chip being picked.
    const empty = M3EShape.largeIncreased;
    final corner = empty - (empty - M3EShape.small) * shapeT.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(corner),
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
              style: theme.textTheme.labelMedium?.copyWith(color: labelColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget chip;
    if (hasValue == null) {
      // Nothing about a neutral chip can change, so it is built once with no
      // controller behind it rather than paying for two springs per chip in
      // the lists these appear in.
      chip = _body(context, 1, 0, dimLabel: false);
    } else {
      final target = hasValue! ? 1.0 : 0.0;
      chip = M3ESpringBuilder(
        // Spatial: the corner is travelling and is allowed to overshoot.
        value: target,
        spring: M3EMotion.fastSpatial,
        builder: (context, shapeT, _) => M3ESpringBuilder(
          // Effects: a fill that sails past its target and comes back reads
          // as a rendering bug rather than as feedback.
          value: target,
          spring: M3EMotion.defaultEffects,
          builder: (context, tintT, __) =>
              _body(context, shapeT, tintT, dimLabel: true),
        ),
      );
    }

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
