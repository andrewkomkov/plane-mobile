import 'package:flutter/material.dart';

import 'motion.dart';

/// The Material 3 Expressive route transition.
///
/// Every screen change in this app used to be a stock Material curve. That is
/// worth stating plainly, because it was the *most frequent* motion in a
/// product whose stated thesis is that motion is springs: 47 pushes, all of
/// them `MaterialPageRoute`, all of them landing on whatever Flutter's platform
/// default happened to be.
///
/// Flutter's own default is honest about the gap. `FadeForwardsPageTransitions`
/// — what Android falls back to when predictive back is not enabled, which is
/// this app's case — carries the comment that its 450ms `easeInOutCubic`
/// "does not match the actual value used by native Android [...] because native
/// Android is using Material 3 Expressive springs that are not currently
/// supported by Flutter". This builder is that missing piece: the same shape of
/// transition, driven by the scheme's own springs.
///
/// [M3EMotion.slowSpatial] carries the movement — the token's table entry has
/// always read "large surfaces travelling a long distance, full-screen
/// transitions", and until now it had no call site. [M3EMotion.defaultEffects]
/// carries the fade, critically damped, because an opacity that overshoots is
/// both a glitch and out of range.
///
/// **Reduce motion** needs no special handling here, unlike [M3ESpringBuilder]:
/// a route runs on `AnimationController.forward()`, which Flutter scales to 5%
/// of its duration when `disableAnimations` is set, so the whole transition
/// collapses to about 22ms on its own.
///
/// **Predictive back** is the one thing this gives up on Android. The framework
/// default wraps every route in `_PredictiveBackGestureDetector`; this does
/// not. Nothing is lost today — the gesture requires
/// `android:enableOnBackInvokedCallback="true"` in the manifest and this app
/// does not set it — but if that flag is ever added, this builder has to grow a
/// predictive-back branch or Android U's back peek will not appear.
class M3ESpringPageTransitionsBuilder extends PageTransitionsBuilder {
  const M3ESpringPageTransitionsBuilder({this.backgroundColor});

  /// Painted behind a route while it is crossing with another one, so the two
  /// fades never expose the window underneath. Defaults to the scaffold colour,
  /// which is what the pages themselves paint.
  final Color? backgroundColor;

  /// Movement. Sampled once — building the curve walks the simulation — so it
  /// is held rather than rebuilt per route.
  static final M3ESpringCurve spatial = M3ESpringCurve(M3EMotion.slowSpatial);

  /// Fades, on their own settle window so both channels finish together.
  static final M3ESpringCurve effects = M3ESpringCurve(M3EMotion.defaultEffects);

  /// The spring's own settle time, so the controller runs the simulation at its
  /// natural rate instead of stretching or clipping it. It lands within a few
  /// milliseconds of the framework's hand-tuned 450ms, which is a reassuring
  /// place for the physics to have arrived at by itself.
  @override
  Duration get transitionDuration => spatial.settleDuration;

  // Four directions, four pairs of tweens, each one driven by an animation that
  // runs 0→1 in its own direction. `DualTransitionBuilder` is what makes that
  // possible, and it is the whole reason the pop looks right: a single curve
  // read backwards would put the spring's overshoot at the wrong end, so a
  // dismissing page would hang and then snap.
  //
  // The arriving page grows into place. 0.92 rather than the stock 0.85: these
  // screens are dense lists, and a larger jump makes the rows visibly reflow
  // rather than settle.
  static final Animatable<double> _enterScale =
      Tween<double>(begin: 0.92, end: 1.0).chain(CurveTween(curve: spatial));
  static final Animatable<double> _enterFade =
      Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: effects));

  static final Animatable<double> _exitScale =
      Tween<double>(begin: 1.0, end: 0.92).chain(CurveTween(curve: spatial));
  static final Animatable<double> _exitFade =
      Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: effects));

  // The covered page keeps travelling in the same direction — away from the
  // viewer — which is what makes a push read as a stack rather than a swap.
  static final Animatable<double> _coveredScale =
      Tween<double>(begin: 1.0, end: 1.04).chain(CurveTween(curve: spatial));
  static final Animatable<double> _coveredFade =
      Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: effects));

  static final Animatable<double> _revealScale =
      Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: spatial));
  static final Animatable<double> _revealFade =
      Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: effects));

  @override
  DelegatedTransitionBuilder? get delegatedTransition => (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        bool allowSnapshotting,
        Widget? child,
      ) =>
          _coveredTransition(context, secondaryAnimation, backgroundColor, child);

  /// What happens to a route while another one covers it.
  static Widget _coveredTransition(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Color? backgroundColor,
    Widget? child,
  ) {
    // Reversed, so that "being covered" — secondaryAnimation running forward —
    // is the branch that gets its own forward-running 0→1 animation.
    final Widget transition = DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder: (context, animation, child) => FadeTransition(
        opacity: _revealFade.animate(animation),
        child: ScaleTransition(
          scale: _revealScale.animate(animation),
          child: child,
        ),
      ),
      reverseBuilder: (context, animation, child) => FadeTransition(
        opacity: _coveredFade.animate(animation),
        child: ScaleTransition(
          scale: _coveredScale.animate(animation),
          child: child,
        ),
      ),
      child: child,
    );

    // A transparent route (a dialog pushed as a page) has to keep showing what
    // is behind it, so it never gets the backdrop.
    final bool isOpaque = ModalRoute.opaqueOf(context) ?? true;
    if (!isOpaque) return transition;

    return ColoredBox(
      color: secondaryAnimation.isAnimating
          ? backgroundColor ?? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      child: transition,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) => FadeTransition(
        opacity: _enterFade.animate(animation),
        child: ScaleTransition(
          scale: _enterScale.animate(animation),
          child: child,
        ),
      ),
      reverseBuilder: (context, animation, child) => IgnorePointer(
        // A page on its way out must not take the taps meant for the one
        // arriving behind it.
        ignoring: animation.status == AnimationStatus.forward,
        child: FadeTransition(
          opacity: _exitFade.animate(animation),
          child: ScaleTransition(
            scale: _exitScale.animate(animation),
            child: child,
          ),
        ),
      ),
      child: _coveredTransition(
        context,
        secondaryAnimation,
        backgroundColor,
        child,
      ),
    );
  }
}
