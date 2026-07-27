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

  /// Offered but not takeable — the server would refuse it.
  ///
  /// Shown rather than hidden, because "you cannot archive this yet" is worth
  /// more than a row that silently is not there; pair it with a [subtitle]
  /// saying why. Dimmed to `0.38`, which is what `M3EIconButton` does and
  /// therefore what disabled looks like in this app.
  final bool enabled;

  const BottomSheetPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.destructive = false,
    this.enabled = true,
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
                itemBuilder: (context, i) => SheetOptionRow<T>(
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

/// The multi-choice bottom sheet.
///
/// [BottomSheetPicker]'s sibling, and the other half of the same problem:
/// seven sheets in this app hand-rolled a `CheckboxListTile` list — four
/// filters in `filter_bar`, and labels, assignees and modules on the work-item
/// screen — with the same disagreements the single-choice sheets had, plus one
/// of their own. A Material checkbox is a 40dp target inside a `dense: true`
/// tile, drawn in `primary` against rows that express selection nowhere else,
/// and it ripples.
///
/// Selection is expressed the same way it is in the single-choice sheet — the
/// surface steps, the corner pulls in, and the mark turns — so a user who has
/// learned one sheet has learned both. The mark is a box rather than a bare
/// check, because it is the one thing that says "more than one of these".
/// Unlike the picker, this one animates: the sheet stays open while the choice
/// changes, so there is a state change on screen to carry, and it is carried
/// by the effects spring rather than a hand-picked curve.
///
/// [show] resolves to the chosen set, or null if the sheet was dismissed —
/// a barrier tap discards, which is what every sheet it replaces did.
class MultiSelectSheet<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<BottomSheetPickerItem<T>> items;
  final Set<T> initialSelection;

  /// What to say when there is nothing to choose from. "No labels" is a
  /// different statement from an empty sheet, which reads as a failure.
  final String emptyMessage;

  /// A row under the options that leaves to make a new one — "Create new
  /// label". The sheet closes as a dismissal first, so a half-made selection
  /// is discarded rather than half-applied, which is what the label sheet this
  /// replaces already did.
  final String? createLabel;
  final VoidCallback? onCreate;

  /// The confirming button's word. "Done" for a filter that is already
  /// applied to a set; "Add" where the sheet exists to add what it returns.
  final String confirmLabel;

  /// Appends the running count — "Add (3)". Worth it where the selection is
  /// the payload rather than a filter; noise where it is not.
  final bool showCount;

  /// Refuses to confirm an empty selection. "Add ()" is not an action, and
  /// the two sheets that meant this drew their own disabled button to say so.
  final bool requireSelection;

  const MultiSelectSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.initialSelection,
    this.emptyMessage = 'Nothing to choose from',
    this.createLabel,
    this.onCreate,
    this.confirmLabel = 'Done',
    this.showCount = false,
    this.requireSelection = false,
  });

  static Future<Set<T>?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<BottomSheetPickerItem<T>> items,
    required Set<T> selected,
    String emptyMessage = 'Nothing to choose from',
    String? createLabel,
    VoidCallback? onCreate,
    String confirmLabel = 'Done',
    bool showCount = false,
    bool requireSelection = false,
  }) {
    return showModalBottomSheet<Set<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => MultiSelectSheet<T>(
        title: title,
        subtitle: subtitle,
        items: items,
        initialSelection: selected,
        emptyMessage: emptyMessage,
        createLabel: createLabel,
        onCreate: onCreate,
        confirmLabel: confirmLabel,
        showCount: showCount,
        requireSelection: requireSelection,
      ),
    );
  }

  @override
  State<MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<MultiSelectSheet<T>> {
  late final Set<T> _selected = Set<T>.from(widget.initialSelection);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: widget.title,
              // The count is the subtitle when the caller has nothing more
              // specific to say: it is the one fact a half-made selection
              // needs and the one the old sheets never showed.
              subtitle: widget.subtitle ??
                  (_selected.isEmpty ? null : '${_selected.length} selected'),
              trailing: _selected.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Clear'),
                    ),
            ),
            if (widget.items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Text(
                  widget.emptyMessage,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: widget.items.length,
                  itemBuilder: (context, i) {
                    final item = widget.items[i];
                    return SheetOptionRow<T>(
                      item: item,
                      selected: _selected.contains(item.value),
                      multiple: true,
                      onTap: () => setState(() {
                        if (!_selected.remove(item.value)) {
                          _selected.add(item.value);
                        }
                      }),
                    );
                  },
                ),
              ),
            if (widget.createLabel != null)
              SheetOptionRow<T?>(
                item: BottomSheetPickerItem<T?>(
                  value: null,
                  label: widget.createLabel!,
                  icon: Icons.add,
                ),
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreate?.call();
                },
              ),
            // The primary action is at the bottom, where a thumb is, rather
            // than in the header where the four filter sheets used to put it.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.requireSelection && _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected),
                  child: Text(widget.showCount
                      ? '${widget.confirmLabel} (${_selected.length})'
                      : widget.confirmLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One option row, for the sheets that cannot be a [BottomSheetPicker].
///
/// The work-item picker has a search field and loads asynchronously, so it
/// cannot hand a fixed list to the picker — but its rows should be the same
/// rows. Exported so that "a row in a sheet" has one implementation rather
/// than the ~70 `ListTile`s the audit counted.
class SheetOptionRow<T> extends StatelessWidget {
  final BottomSheetPickerItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  /// Whether this row belongs to a sheet that takes more than one answer.
  ///
  /// Changes the mark from a check that is absent when unselected to a box
  /// that is always there — an empty box is how a row says "you may pick
  /// several of us" before anything is picked — and animates the change,
  /// because the sheet stays open to see it.
  final bool multiple;

  const SheetOptionRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.multiple = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Disabled dims everything the row draws, foreground included. Dimming
    // the icon alone — which is what the work-item menu did — reads as an icon
    // that happens to be pale, not as a row that cannot be taken.
    double dim(double alpha) => item.enabled ? alpha : alpha * 0.38;
    Color faded(Color c) =>
        item.enabled ? c : c.withValues(alpha: dim(c.a.toDouble()));

    final foreground =
        faded(item.destructive ? scheme.error : scheme.onSurface);
    final accent = faded(item.destructive ? scheme.error : scheme.primary);

    final leading = item.leading ??
        (item.icon == null
            ? null
            : Icon(
                item.icon,
                size: PlaneTheme.iconLarge,
                color: faded(item.iconColor ??
                    (item.destructive
                        ? scheme.error
                        : scheme.onSurfaceVariant)),
              ));

    // Selection steps the surface and pulls the corner in, the same pair of
    // channels M3EChip uses to mean the same thing.
    Widget body(double t) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Color.lerp(
                Colors.transparent, scheme.surfaceContainerHigh, t.clamp(0, 1)),
            borderRadius: BorderRadius.circular(
              // Reads as a corner, not as a number: the row travels between
              // the two shape tokens rather than between two literals.
              M3EShape.large +
                  (M3EShape.small - M3EShape.large) * t.clamp(0, 1),
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
                            ?.copyWith(color: faded(scheme.onSurfaceVariant)),
                      ),
                    ],
                  ],
                ),
              ),
              if (multiple) ...[
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: PlaneTheme.iconLarge,
                  color: selected ? accent : scheme.onSurfaceVariant,
                ),
              ] else if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: PlaneTheme.iconLarge, color: accent),
              ],
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: M3EPressable(
        // Shallower than a card's squeeze: a sheet row is wide and a deep
        // scale on it reads as the whole sheet moving.
        pressedScale: 0.98,
        onTap: item.enabled ? onTap : null,
        selected: selected,
        // The row's own node replaces everything drawn inside it, so the
        // subtitle and the selected state have to be spelled out or they are
        // invisible to a screen reader and to `tool/adb_drive.py`. A dimmed
        // row is invisible to both, so it says so in words.
        semanticLabel: [
          item.label,
          if (!item.enabled) 'unavailable',
          if (item.subtitle != null) item.subtitle!,
        ].join(', '),
        // Single choice does not animate: choosing an option closes the sheet,
        // so there is no state change left on screen to carry.
        child: multiple
            ? M3ESpringBuilder(
                value: selected ? 1 : 0,
                spring: M3EMotion.defaultEffects,
                builder: (context, t, _) => body(t),
              )
            : body(selected ? 1 : 0),
      ),
    );
  }
}
