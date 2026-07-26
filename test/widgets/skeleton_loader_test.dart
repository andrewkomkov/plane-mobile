import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/skeleton_loader.dart';

void main() {
  /// The alpha the shimmer is currently painting its blocks at.
  double shimmerAlpha(WidgetTester tester) {
    final container = tester.widgetList<Container>(find.byType(Container)).first;
    return (container.decoration! as BoxDecoration).color!.a;
  }

  Widget wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  group('skeleton shimmer', () {
    testWidgets('pulses by default', (tester) async {
      await tester.pumpWidget(wrap(const IssueListSkeleton(itemCount: 2)));
      final start = shimmerAlpha(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(shimmerAlpha(tester), isNot(closeTo(start, 0.001)));

      // The pulse never ends, so the tree has to be torn down by hand or the
      // ticker outlives the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('holds still when the user asked for no animation',
        (tester) async {
      // This is the one animation in the app the framework does not rescue.
      // Everything else runs on `forward()`/`reverse()`, which Flutter scales
      // to 5% under disableAnimations; `repeat()` is not scaled at all, so the
      // loading state of every list screen pulsed at full speed at exactly the
      // moment a reduce-motion user was sitting looking at it.
      await tester.pumpWidget(
          wrap(const IssueListSkeleton(itemCount: 2), reduceMotion: true));
      final start = shimmerAlpha(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shimmerAlpha(tester), closeTo(start, 0.001));

      // Held between the two ends: 0.3 is nearly invisible and 0.7 reads as
      // real content.
      expect(start, closeTo(0.5, 0.001));
    });

    testWidgets('every skeleton in the file honours it', (tester) async {
      for (final skeleton in <Widget>[
        const SkeletonList(itemCount: 2),
        const IssueListSkeleton(itemCount: 2),
        const ProjectListSkeleton(itemCount: 2),
        const IssueDetailSkeleton(),
        const InboxSkeleton(itemCount: 2),
      ]) {
        await tester.pumpWidget(wrap(skeleton, reduceMotion: true));
        final start = shimmerAlpha(tester);
        await tester.pump(const Duration(milliseconds: 500));
        expect(shimmerAlpha(tester), closeTo(start, 0.001),
            reason: '${skeleton.runtimeType} still pulses');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('starts pulsing again if the setting is turned back off',
        (tester) async {
      await tester.pumpWidget(
          wrap(const IssueListSkeleton(itemCount: 2), reduceMotion: true));
      await tester.pumpWidget(wrap(const IssueListSkeleton(itemCount: 2)));

      final start = shimmerAlpha(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(shimmerAlpha(tester), isNot(closeTo(start, 0.001)));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
