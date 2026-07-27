import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';

/// A Plane label colour, as the server writes it.
///
/// `#RRGGBB`, sometimes `RRGGBB`, sometimes `AARRGGBB`, and sometimes a string
/// nobody thought about. This was implemented five times — in `issue_row`,
/// `filter_bar`, `project_settings` and twice in `issue_detail` — with the
/// same three lines and the same grey fallback in each.
Color parseHexColor(String hex, {Color? fallback}) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  // The old copies each fell back to a literal `0xFF999999`, which belongs to
  // neither theme. `outline` is the role for "a boundary we could not name".
  return parsed == null ? (fallback ?? const Color(0xFF908F9E)) : Color(parsed);
}

/// One label, as a tinted pill with the label's own colour.
///
/// There were two of these — `issue_row.dart` and `issue_detail_screen.dart` —
/// drawing the same concept from the same data, and they had already drifted
/// in three dimensions: 3dp of vertical padding against 4, a 6dp dot against
/// 8, `labelSmall` against `labelMedium`. One of them also had no press
/// response and the other had Material ink.
///
/// The row's cut is the smaller one, because a work-item row can carry several
/// pills beside a title and everything else on that row is `labelSmall`. The
/// detail screen's is the larger, because there the pills are the content of
/// their own section rather than metadata on a line. That is a real
/// distinction, so it is a parameter — [dense] — rather than two widgets.
class LabelPill extends StatelessWidget {
  final String name;
  final String hex;

  /// The row cut: tighter padding, a smaller dot, `labelSmall`.
  final bool dense;

  /// Opens the label picker. The pill is a control when this is set, and says
  /// so — several sit in one row, so the name stays in the spoken label to
  /// keep them apart.
  final VoidCallback? onTap;

  const LabelPill({
    super.key,
    required this.name,
    required this.hex,
    this.dense = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        parseHexColor(hex, fallback: Theme.of(context).colorScheme.outline);
    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 6 : 8,
            height: dense ? 6 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: dense
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      label: 'Label $name. Tap to edit labels',
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: M3EPressable(
        pressedScale: 0.94,
        onTap: onTap,
        borderRadius: BorderRadius.circular(M3EShape.full),
        // Matches PropertyChip exactly: a 48dp target with the pill centred in
        // it. These share a Wrap with the property chips, and a 22dp pill
        // beside a 48dp one is what made those rows look ragged.
        child: SizedBox(
          height: 48,
          child: Center(widthFactor: 1.0, child: pill),
        ),
      ),
    );
  }
}
