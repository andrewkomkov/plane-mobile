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

/// A spring simulation replayed as a [Curve].
///
/// [M3ESpringBuilder] is the honest way to run a spring — it retargets with the
/// current velocity and never needs a duration — and it is what everything in
/// this app that owns its own animation uses. Routes are the exception: a
/// [PageRoute] owns an `AnimationController`, drives it with a duration, and
/// hands `buildTransitions` a plain 0→1 `Animation`. There is no seam to push a
/// `Simulation` into. So for that one case the simulation is sampled ahead of
/// time and worn as a curve.
///
/// The sample window is the spring's own [settleTime], mapped onto the unit
/// interval: the *shape* is the real spring, including its overshoot, and only
/// the clock is borrowed. A route that uses this curve should take [settleTime]
/// as its duration so the two agree and the motion runs at its natural rate.
///
/// [restDelta] is how close to the target counts as arrived. The default 1%
/// rather than the framework's 0.1% is deliberate: the last 0.9% of a spring's
/// travel is invisible, and waiting for it would add ~150ms of nothing to every
/// screen change.
class M3ESpringCurve extends Curve {
  final SpringSimulation _simulation;

  /// How long the simulation takes to come to rest, in seconds.
  final double settleTime;

  M3ESpringCurve(SpringDescription spring, {double restDelta = 0.01})
      : this._(
          SpringSimulation(
            spring,
            0,
            1,
            0,
            tolerance: Tolerance(
              distance: restDelta,
              // Position is what is visible; the velocity gate only has to stop
              // `isDone` firing while the spring is passing through its target
              // at speed.
              velocity: restDelta * 10,
            ),
          ),
        );

  M3ESpringCurve._(SpringSimulation simulation)
      : _simulation = simulation,
        settleTime = _settleTimeOf(simulation);

  /// Rounded to whole milliseconds, ready for an `AnimationController`.
  Duration get settleDuration =>
      Duration(microseconds: (settleTime * Duration.microsecondsPerSecond).round());

  static double _settleTimeOf(SpringSimulation simulation) {
    // 240Hz, so the answer is finer than any frame that will render it.
    const double step = 1 / 240;
    double t = step;
    // Two seconds is far past any spring in the scheme; the fallback exists so
    // a mistyped stiffness cannot hang the app at startup.
    while (t < 2.0) {
      if (simulation.isDone(t)) return t;
      t += step;
    }
    return 2.0;
  }

  @override
  double transformInternal(double t) => _simulation.x(t * settleTime);
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
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = widget.value;
      return;
    }
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
    // Respect the system's reduce-motion setting. Every moving thing in this
    // app is a spring, so honouring it here covers the whole surface — the
    // value snaps to its target and the simulation never runs.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      if (_controller.value != widget.value) {
        _controller.value = widget.value;
      }
      return widget.builder(context, widget.value, widget.child);
    }
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

  /// Re-declared on the semantics node alongside [onTap]. A labelled control
  /// excludes its subtree, which would otherwise drop this action from
  /// assistive tech entirely.
  final VoidCallback? onDoubleTap;

  /// Names what [onLongPress] does, e.g. "remove from this module".
  ///
  /// A long-press is announced by TalkBack as an available action but not as a
  /// *particular* one, so a row whose only route to an action is the long-press
  /// tells a screen-reader user that something is there without saying what.
  /// The hint is what turns it into an offer.
  final String? longPressHint;

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
    this.onDoubleTap,
    this.longPressHint,
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
      onDoubleTap: widget.onDoubleTap,
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

    final labelled = widget.semanticLabel != null;
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      selected: widget.selected,
      container: labelled,
      // An explicit label REPLACES the subtree's, rather than being appended to
      // it. Without excluding, a control that both carries a label and renders
      // that same word as visible text — the active nav destination — reports
      // "Projects\nProjects": announced twice by a screen reader, and missed by
      // any automation matching the label exactly, on the one destination a
      // navigation script cares about most.
      //
      // Excluding the subtree would also drop the child GestureDetector's tap
      // action, so the action is re-declared on this node to keep the control
      // operable from assistive tech.
      excludeSemantics: labelled,
      onTap: labelled ? widget.onTap : null,
      onLongPress: labelled ? widget.onLongPress : null,
      onLongPressHint: labelled ? widget.longPressHint : null,
      child: gesture,
    );
  }
}
