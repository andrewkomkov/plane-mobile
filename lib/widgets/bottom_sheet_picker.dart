import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';
import '../config/theme.dart';
import 'sheet_header.dart';

/// One row in a [BottomSheetPicker].
class BottomSheetPickerItem<T> {
  final T value;
  final String label;

  /// A second line — what the option means. The role picker uses it; most
  /// pickers do not need it.
  final String? subtitle;

  /// Leading glyph. Prefer this over [leading] so every row lines up.
  final IconData? icon;

  /// Overrides the icon colour, for a state hue or a priority.
  final Color? iconColor;

  /// Arbitrary leading widget for the rows an icon cannot express — an avatar,
  /// a colour swatch. Wins over [icon].
  final Widget? leading;

  /// Draws in the error role. Presentational only: whether the action needs
  /// confirming is the caller's decision, because only it knows what it costs.
  /// See `confirmDestructive`.
  final bool destructive;

  const BottomSheetPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.destructive = false,
  });
}

/// The single-choice bottom sheet.
///
/// This existed before and was used nowhere, while 45 sheets hand-rolled the
/// same thing and disagreed about all of it: header role, item text role,
/// whether the current value is even marked, four different check treatments,
/// and — every one of them — Material ink where the rest of the app has a
/// spring.
///
/// What this fixes, so that adopting it is a strict improvement at every one of
/// those sites:
///
/// - **Press is the app's press.** [M3EPressable], not `ListTile` ink. The
///   sheet was the last interaction surface in the app still rippling.
/// - **Selection is carried by three channels**, not by a check alone: a
///   stepped surface, the tighter corner that [M3EChip] uses for the same
///   meaning, and a tinted check. Colour-blind users and the light ramp both
///   need more than one.
/// - **Rows are 48dp.** `ListTile` gave that for free and hand-rolled `Row`s
///   did not.
/// - **Every row names itself.** [M3EPressable] replaces its subtree's
///   semantics, so the label is assembled here — including the selected state —
///   or `tool/adb_drive.py` sees an anonymous node.
/// - **It scrolls.** The old version was a `Column`, which overflows the moment
///   a workspace has more projects than fit on screen.
class BottomSheetPicker<T> extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<BottomSheetPickerItem<T>> items;

  /// The current value. Compared with `==`, so a picker that offers an explicit
  /// "None" should give it a real sentinel value rather than null.
  final T? selectedValue;

  final ValueChanged<T> onSelected;

  const BottomSheetPicker({
    super.key,
    this.title,
    this.subtitle,
    required this.items,
    this.selectedValue,
    required this.onSelected,
  });

  /// Opens the picker and resolves to the chosen value, or null if dismissed.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required List<BottomSheetPickerItem<T>> items,
    T? selectedValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // A picker is as tall as its contents up to the cap below, which the
      // default 9/16 limit would otherwise clip for no reason.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => BottomSheetPicker<T>(
        title: title,
        subtitle: subtitle,
        items: items,
        selectedValue: selectedValue,
        onSelected: (value) => Navigator.pop(ctx, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // Enough of the screen behind it stays visible that the sheet still
        // reads as a layer over the list it came from.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) SheetHeader(title: title!, subtitle: subtitle),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: items.length,
                itemBuilder: (context, i) => _PickerRow<T>(
                  item: items[i],
                  selected: items[i].value == selectedValue,
                  onTap: () => onSelected(items[i].value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  final BottomSheetPickerItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  const _PickerRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final foreground = item.destructive ? scheme.error : scheme.onSurface;
    final accent = item.destructive ? scheme.error : scheme.primary;

    final leading = item.leading ??
        (item.icon == null
            ? null
            : Icon(
                item.icon,
                size: PlaneTheme.iconLarge,
                color: item.iconColor ??
                    (item.destructive ? scheme.error : scheme.onSurfaceVariant),
              ));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: M3EPressable(
        // Shallower than a card's squeeze: a sheet row is wide and a deep
        // scale on it reads as the whole sheet moving.
        pressedScale: 0.98,
        onTap: onTap,
        selected: selected,
        // The row's own node replaces everything drawn inside it, so the
        // subtitle and the selected state have to be spelled out or they are
        // invisible to a screen reader and to `tool/adb_drive.py`.
        semanticLabel: [
          item.label,
          if (item.subtitle != null) item.subtitle!,
        ].join(', '),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Selection steps the surface and pulls the corner in, the same
            // pair of channels M3EChip uses to mean the same thing. Nothing
            // animates: choosing an option closes the sheet, so there is no
            // state change on screen to carry.
            color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(
              selected ? M3EShape.small : M3EShape.large,
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: PlaneTheme.iconLarge, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
