import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/m3e/motion.dart';
import 'package:plane_mobile/config/m3e/page_transitions.dart';
import 'package:plane_mobile/config/theme.dart';

void main() {
  group('M3ESpringCurve', () {
    test('starts at 0, ends at 1 and overshoots in between', () {
      final curve = M3ESpringCurve(M3EMotion.slowSpatial);

      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);

      // The spatial springs are underdamped on purpose — a spatial transition
      // that cannot overshoot is a curve with extra steps.
      double peak = 0;
      for (int i = 0; i <= 200; i++) {
        peak = peak > curve.transform(i / 200) ? peak : curve.transform(i / 200);
      }
      expect(peak, greaterThan(1.0));
    });

    test('an effects spring never overshoots', () {
      final curve = M3ESpringCurve(M3EMotion.defaultEffects);
      for (int i = 0; i <= 200; i++) {
        expect(curve.transform(i / 200), lessThanOrEqualTo(1.0));
      }
    });

    test('settles in a duration a route can use', () {
      // Not an arbitrary bound: the framework's own hand-tuned approximation of
      // this transition is 450ms, and the physics landing in the same place is
      // the reason it can be swapped in without anything feeling different.
      final settle = M3ESpringPageTransitionsBuilder.spatial.settleDuration;
      expect(settle.inMilliseconds, greaterThan(250));
      expect(settle.inMilliseconds, lessThan(600));
    });

    test('a stiffer spring settles sooner', () {
      expect(
        M3ESpringCurve(M3EMotion.fastSpatial).settleTime,
        lessThan(M3ESpringCurve(M3EMotion.slowSpatial).settleTime),
      );
    });
  });

  group('PageTransitionsTheme', () {
    test('the spring builder is installed on both themes, per platform', () {
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        final builders = theme.pageTransitionsTheme.builders;
        expect(builders[TargetPlatform.android],
            isA<M3ESpringPageTransitionsBuilder>());
        // iOS keeps Cupertino, because that is what carries the interactive
        // edge-swipe back gesture.
        expect(builders[TargetPlatform.iOS],
            isA<CupertinoPageTransitionsBuilder>());
      }
    });

    testWidgets('a push animates and lands', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: PlaneTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('second')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pump();
      // Mid-flight the arriving page is on screen but not yet at full size.
      await tester.pump(const Duration(milliseconds: 80));
      // Scoped to the arriving page: a Scaffold builds a ScaleTransition of
      // its own for the FAB slot whether or not it has one.
      final midScale = tester
          .widgetList<ScaleTransition>(find.ancestor(
            of: find.text('second'),
            matching: find.byType(ScaleTransition),
          ))
          .map((t) => t.scale.value)
          .reduce((a, b) => a < b ? a : b);
      expect(midScale, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('a pop returns to the page underneath', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: PlaneTheme.light(),
        home: const Scaffold(body: Text('first')),
      ));

      navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    });

    testWidgets('reduce motion collapses the transition', (tester) async {
      // Route transitions run on an AnimationController, which the framework
      // itself scales to 5% under disableAnimations. This pins that the
      // transition inherits that rather than fighting it — one pump past the
      // scaled duration and the new page is fully arrived.
      //
      // The flag has to be set on the binding, not through a MediaQuery:
      // `AnimationController` reads `SemanticsBinding.disableAnimations`
      // directly, and a widget-level MediaQuery would not reach it.
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: PlaneTheme.dark(),
        home: const Scaffold(body: Text('first')),
      ));

      navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second')),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final scales = tester
          .widgetList<ScaleTransition>(find.ancestor(
            of: find.text('second'),
            matching: find.byType(ScaleTransition),
          ))
          .map((t) => t.scale.value);
      for (final scale in scales) {
        expect(scale, moreOrLessEquals(1.0, epsilon: 0.001));
      }
      expect(find.text('second'), findsOneWidget);
    });
  });
}
