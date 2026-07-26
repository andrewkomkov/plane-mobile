import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/plane_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PlaneRow', () {
    testWidgets('fills the slots it is given', (tester) async {
      await tester.pumpWidget(wrap(const PlaneRow(
        icon: Icons.description_outlined,
        identifier: 'PROJ-7',
        title: 'Release notes',
        subtitle: 'updated today',
        subtitleTrailing: '3/8',
        semanticLabel: 'Release notes',
      )));

      expect(find.text('PROJ-7'), findsOneWidget);
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('updated today'), findsOneWidget);
      // Separated from the subtitle by a bullet, so the two do not run
      // together when a screen reader reads the line.
      expect(find.text(' • 3/8'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('a slot left empty draws nothing', (tester) async {
      await tester.pumpWidget(wrap(const PlaneRow(
        title: 'Bare',
        semanticLabel: 'Bare',
      )));

      expect(find.text('Bare'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders a progress bar only when given progress',
        (tester) async {
      await tester.pumpWidget(wrap(const PlaneRow(
        title: 'Cycle 4',
        progress: 0.5,
        semanticLabel: 'Cycle 4',
      )));

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0.5);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(PlaneRow(
        title: 'Tap me',
        semanticLabel: 'Tap me',
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(PlaneRow));
      expect(tapped, isTrue);
    });

    testWidgets('squeezes the whole surface while pressed, trailing included',
        (tester) async {
      // Only the content region owns the gesture, so this is the check that
      // the card still moves as one piece: press the title and the trailing
      // slot — which is outside that region — has to travel with it.
      const trailingKey = Key('trailing');
      await tester.pumpWidget(wrap(PlaneRow(
        title: 'Press me',
        semanticLabel: 'Press me',
        onTap: () {},
        trailing: const SizedBox(key: trailingKey, width: 24, height: 24),
      )));

      final titleAtRest = tester.getRect(find.text('Press me'));
      final trailingAtRest = tester.getRect(find.byKey(trailingKey));

      final press =
          await tester.startGesture(tester.getCenter(find.text('Press me')));
      // Past the tap deadline, then far enough into the spring to have moved.
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 48));

      expect(tester.getRect(find.text('Press me')).width,
          lessThan(titleAtRest.width));
      expect(tester.getRect(find.byKey(trailingKey)).left,
          isNot(closeTo(trailingAtRest.left, 0.01)));

      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('names itself for automation and screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(PlaneRow(
        title: 'Login bug',
        semanticLabel: 'PLM-3, Login bug, state Todo',
        onTap: () {},
      )));

      expect(find.bySemanticsLabel('PLM-3, Login bug, state Todo'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('a trailing action keeps its own name', (tester) async {
      // The regression this guards: M3EPressable's label REPLACES the
      // subtree's semantics, so a button drawn inside the row would be
      // invisible to `adb shell uiautomator` and to a screen reader. The
      // trailing slot sits outside that node for exactly this reason.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(PlaneRow(
        title: 'My view',
        semanticLabel: 'My view, view',
        onTap: () {},
        trailing: Semantics(
          label: 'Delete view My view',
          button: true,
          child: const SizedBox(width: 32, height: 32),
        ),
      )));

      expect(find.bySemanticsLabel('My view, view'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete view My view'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('carries selected state onto the semantics node',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(PlaneRow(
        title: 'Active',
        semanticLabel: 'Active row',
        selected: true,
        onTap: () {},
      )));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Active row')),
        isSemantics(label: 'Active row', isSelected: true),
      );
      handle.dispose();
    });

    testWidgets(
        'the compact density drops the fill but keeps the text position',
        (tester) async {
      Future<double> titleLeft(PlaneRowDensity density) async {
        await tester.pumpWidget(wrap(PlaneRow(
          title: 'Same place',
          density: density,
          semanticLabel: 'Same place',
        )));
        return tester.getTopLeft(find.text('Same place')).dx;
      }

      final standard = await titleLeft(PlaneRowDensity.standard);
      final compact = await titleLeft(PlaneRowDensity.compact);
      expect(compact, standard);
    });

    testWidgets('the card density stacks its slots instead of spreading them',
        (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(
        width: 280,
        child: PlaneRow(
          identifier: 'PLM-3',
          title: 'A board card',
          density: PlaneRowDensity.card,
          semanticLabel: 'PLM-3, A board card',
          metadata: [
            PlaneRowMeta(icon: Icons.subdirectory_arrow_right, text: '2')
          ],
        ),
      )));

      // The indicator sits under the title on a card, not beside it.
      final title = tester.getTopLeft(find.text('A board card'));
      final meta = tester.getTopLeft(find.text('2'));
      expect(meta.dy, greaterThan(title.dy));
    });
  });

  group('PlaneAvatarStack', () {
    testWidgets('shows at most three', (tester) async {
      await tester.pumpWidget(wrap(const PlaneAvatarStack(avatars: [
        PlaneAvatar(name: 'Ann'),
        PlaneAvatar(name: 'Bob'),
        PlaneAvatar(name: 'Cyd'),
        PlaneAvatar(name: 'Dee'),
      ])));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
    });

    testWidgets('falls back to an initial when there is no avatar image',
        (tester) async {
      await tester.pumpWidget(wrap(const PlaneAvatarStack(
        avatars: [PlaneAvatar(name: 'zoe')],
      )));

      expect(find.text('Z'), findsOneWidget);
    });
  });
}
