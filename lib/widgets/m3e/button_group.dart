import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';

class M3EButtonGroupItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const M3EButtonGroupItem({required this.label, this.icon, this.onPressed});
}

/// Material 3 Expressive **ButtonGroup**.
///
/// The defining behaviour is the width interplay: pressing a button makes it
/// grow while its immediate neighbours compress to make room, then everything
/// springs back. That physical give is what separates a ButtonGroup from a row
/// of buttons, so it is implemented properly here — one spring per item, all
/// resolved in a single layout pass — rather than faked with a scale transform.
///
/// Works in two modes: as a selection control ([selectedIndex] non-null, the
/// M3E replacement for SegmentedButton) or as a plain row of actions.
class M3EButtonGroup extends StatefulWidget {
  final List<M3EButtonGroupItem> items;

  /// When non-null the group behaves as a single-select control.
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  /// Connected groups share a hairline gap and square inner corners; separated
  /// groups keep every button fully rounded.
  final bool connected;

  final double height;

  /// How much the pressed button grows, as a fraction of its resting weight.
  final double pressExpansion;

  const M3EButtonGroup({
    super.key,
    required this.items,
    this.selectedIndex,
    this.onSelected,
    this.connected = true,
    this.height = 44,
    this.pressExpansion = 0.35,
  });

  @override
  State<M3EButtonGroup> createState() => _M3EButtonGroupState();
}

class _M3EButtonGroupState extends State<M3EButtonGroup>
    with TickerProviderStateMixin {
  /// Per-item expansion, 0 at rest. Positive for the pressed button, negative
  /// for its neighbours.
  late List<AnimationController> _weights;
  late Listenable _merged;

  static const double _gap = 2;

  @override
  void initState() {
    super.initState();
    _buildControllers();
  }

  void _buildControllers() {
    _weights = List.generate(
      widget.items.length,
      (_) => AnimationController.unbounded(value: 0, vsync: this),
    );
    _merged = Listenable.merge(_weights);
  }

  @override
  void didUpdateWidget(M3EButtonGroup old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      for (final c in _weights) {
        c.dispose();
      }
      _buildControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _weights) {
      c.dispose();
    }
    super.dispose();
  }

  void _animateTo(int index, double target) {
    final c = _weights[index];
    c.animateWith(
      SpringSimulation(M3EMotion.fastSpatial, c.value, target, c.velocity),
    );
  }

  void _onPressedChanged(int index, bool pressed) {
    for (int i = 0; i < _weights.length; i++) {
      final double target;
      if (!pressed) {
        target = 0;
      } else if (i == index) {
        target = widget.pressExpansion;
      } else if ((i - index).abs() == 1) {
        // Only the immediate neighbours give way — the rest of the row holds
        // still, which keeps the group's overall width visually stable.
        target = -widget.pressExpansion / 2;
      } else {
        target = 0;
      }
      _animateTo(i, target);
    }
  }

  BorderRadius _cornersFor(int index) {
    if (!widget.connected) {
      return BorderRadius.circular(M3EShape.full);
    }
    final isFirst = index == 0;
    final isLast = index == widget.items.length - 1;
    const outer = Radius.circular(M3EShape.full);
    const inner = Radius.circular(M3EShape.small);
    return BorderRadius.only(
      topLeft: isFirst ? outer : inner,
      bottomLeft: isFirst ? outer : inner,
      topRight: isLast ? outer : inner,
      bottomRight: isLast ? outer : inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _merged,
            builder: (context, _) {
              final weights = [
                for (int i = 0; i < widget.items.length; i++)
                  (1.0 + _weights[i].value).clamp(0.2, 3.0),
              ];
              final totalWeight = weights.fold<double>(0, (a, b) => a + b);
              final available =
                  constraints.maxWidth - _gap * (widget.items.length - 1);

              return Row(
                children: [
                  for (int i = 0; i < widget.items.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: available * weights[i] / totalWeight,
                      child: _buildButton(context, i, scheme),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildButton(BuildContext context, int index, ColorScheme scheme) {
    final item = widget.items[index];
    final isSelected = widget.selectedIndex == index;

    // Matches the library: Compose's ButtonGroup builds on ToggleButton, whose
    // checked state fills with `primary`, not `primaryContainer`. Using the
    // container role here made the Dart group and the Compose-backed one render
    // visibly different colours for the same state on the same screen.
    final restBackground = scheme.surfaceContainerHigh;
    final selectedBackground = scheme.primary;
    final restForeground = scheme.onSurfaceVariant;
    final selectedForeground = scheme.onPrimary;

    return M3EPressable(
      pressedScale: 1.0, // width already responds; scaling too would double up
      // The label comes from the child Text; only the selection state needs
      // declaring, so automation and screen readers can tell which is active.
      selected: widget.selectedIndex == null ? null : isSelected,
      onPressedChanged: (pressed) => _onPressedChanged(index, pressed),
      onTap: () {
        if (widget.onSelected != null) widget.onSelected!(index);
        item.onPressed?.call();
      },
      // The corners here are fixed per position, so selection changes nothing
      // but colour — one effects spring, critically damped, rather than a
      // hand-picked 180ms curve.
      child: M3ESpringBuilder(
        value: isSelected ? 1 : 0,
        spring: M3EMotion.defaultEffects,
        builder: (context, tintT, _) {
          final t = tintT.clamp(0.0, 1.0);
          final background = Color.lerp(restBackground, selectedBackground, t)!;
          final foreground = Color.lerp(restForeground, selectedForeground, t)!;

          return Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: _cornersFor(index),
            ),
            alignment: Alignment.center,
            child: ClipRect(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: foreground,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
