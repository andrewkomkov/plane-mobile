import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Material 3 Expressive motion scheme.
///
/// M3 Expressive replaces duration+easing with physics: every transition is a
/// spring described by stiffness and damping ratio. Spatial springs move things
/// (position, size, shape) and are allowed to overshoot; effects springs change
/// non-spatial properties (color, opacity, elevation) and never overshoot,
/// because a colour that bounces past its target reads as a glitch.
///
/// Values mirror the `MotionScheme` tokens shipped in material3 1.5.0-alpha24.
class M3EMotion {
  const M3EMotion._();

  // ─── Expressive spatial: bouncy, used for anything that moves ───

  /// Small, immediate movement — press states, icon nudges, chip selection.
  static final SpringDescription fastSpatial = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 800.0,
    ratio: 0.6,
  );

  /// The workhorse — sheets, list reordering, nav indicator, FAB menu items.
  static final SpringDescription defaultSpatial = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 380.0,
    ratio: 0.8,
  );

  /// Large surfaces travelling a long distance — full-screen transitions.
  static final SpringDescription slowSpatial = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 200.0,
    ratio: 0.8,
  );

  // ─── Expressive effects: critically damped, never overshoots ───

  static final SpringDescription fastEffects = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 3800.0,
    ratio: 1.0,
  );

  static final SpringDescription defaultEffects = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 1600.0,
    ratio: 1.0,
  );

  static final SpringDescription slowEffects = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 800.0,
    ratio: 1.0,
  );

  // ─── Standard (non-expressive) scheme, for surfaces that should stay calm ───

  static final SpringDescription standardSpatial = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 700.0,
    ratio: 0.9,
  );

  /// Duration tokens are still needed where a spring makes no sense — staggered
  /// delays, autoscroll, indeterminate loops.
  static const Duration stagger = Duration(milliseconds: 30);
  static const Duration morphCycle = Duration(milliseconds: 650);
}

/// Drives a single `double` toward [value] with a spring simulation.
///
/// Flutter has no built-in "animate to target with physics" widget: implicit
/// widgets are duration+curve based, which cannot express overshoot that
/// depends on current velocity. This does the real thing — when the target
/// changes mid-flight the new simulation inherits the current velocity, so
/// rapid taps blend instead of restarting.
class M3ESpringBuilder extends StatefulWidget {
  final double value;
  final SpringDescription spring;
  final Widget Function(BuildContext context, double value, Widget? child) builder;
  final Widget? child;

  const M3ESpringBuilder({
    super.key,
    required this.value,
    required this.spring,
    required this.builder,
    this.child,
  });

  @override
  State<M3ESpringBuilder> createState() => _M3ESpringBuilderState();
}

class _M3ESpringBuilderState extends State<M3ESpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Unbounded: a spatial spring legitimately overshoots past 1.0.
    _controller = AnimationController.unbounded(
      value: widget.value,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(M3ESpringBuilder old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.animateWith(
        SpringSimulation(
          widget.spring,
          _controller.value,
          widget.value,
          _controller.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
    );
  }
}

/// Press-and-hold scale, the signature M3 Expressive touch feedback.
///
/// Squeezes on press with a fast spatial spring and releases with overshoot.
/// Wrap any tappable surface; it forwards gestures rather than swallowing them.
class M3EPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale at full press. 0.96 for cards, ~0.92 for small buttons.
  final double pressedScale;
  final BorderRadius? borderRadius;

  /// Reports press progress (0→1) so parents can react — a button group uses
  /// this to widen the pressed child and squeeze its neighbours.
  final ValueChanged<bool>? onPressedChanged;

  /// Accessibility label.
  ///
  /// Required in practice for icon-only controls: without it the control is
  /// invisible to screen readers *and* to `adb shell uiautomator`, which is how
  /// this app is driven from the outside. A control whose child renders text
  /// does not need one — Flutter derives the label from that text.
  final String? semanticLabel;

  /// Marks the node as selected, so automation and screen readers can tell
  /// which destination or filter is currently active.
  final bool? selected;

  const M3EPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.borderRadius,
    this.onPressedChanged,
    this.semanticLabel,
    this.selected,
  });

  @override
  State<M3EPressable> createState() => _M3EPressableState();
}

class _M3EPressableState extends State<M3EPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final gesture = GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: M3ESpringBuilder(
        value: _pressed ? widget.pressedScale : 1.0,
        spring: M3EMotion.fastSpatial,
        child: widget.child,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
      ),
    );

    if (widget.semanticLabel == null && widget.selected == null) {
      return gesture;
    }
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      selected: widget.selected,
      // The label replaces whatever the subtree would have produced, so an
      // icon-only control reports one clean node instead of nothing.
      container: widget.semanticLabel != null,
      child: gesture,
    );
  }
}
