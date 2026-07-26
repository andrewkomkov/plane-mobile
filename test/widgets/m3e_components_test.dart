import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/m3e/motion.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/config/m3e/shapes.dart';
import 'package:plane_mobile/widgets/m3e/app_bar.dart';
import 'package:plane_mobile/widgets/m3e/button_group.dart';
import 'package:plane_mobile/widgets/m3e/chip.dart';
import 'package:plane_mobile/widgets/m3e/fab_menu.dart';
import 'package:plane_mobile/widgets/m3e/flexible_app_bar.dart';
import 'package:plane_mobile/widgets/m3e/loading_indicator.dart';
import 'package:plane_mobile/widgets/m3e/native.dart';
import 'package:plane_mobile/widgets/m3e/split_button.dart';
import 'package:plane_mobile/widgets/m3e/text_field.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('M3EButtonGroup', () {
    testWidgets('renders every item', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(
        width: 320,
        child: M3EButtonGroup(
          items: [
            M3EButtonGroupItem(label: 'Assigned'),
            M3EButtonGroupItem(label: 'Created'),
            M3EButtonGroupItem(label: 'All'),
          ],
          selectedIndex: 0,
        ),
      )));

      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('reports the tapped index', (tester) async {
      int? selected;
      await tester.pumpWidget(wrap(SizedBox(
        width: 320,
        child: M3EButtonGroup(
          items: const [
            M3EButtonGroupItem(label: 'One'),
            M3EButtonGroupItem(label: 'Two'),
          ],
          selectedIndex: 0,
          onSelected: (i) => selected = i,
        ),
      )));

      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(selected, 1);
    });

    testWidgets('pressed item grows and its neighbour compresses',
        (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(
        width: 300,
        child: M3EButtonGroup(
          items: [
            M3EButtonGroupItem(label: 'One'),
            M3EButtonGroupItem(label: 'Two'),
            M3EButtonGroupItem(label: 'Three'),
          ],
          selectedIndex: 0,
        ),
      )));

      // The nearest Container ancestor is the button's own painted box. It
      // used to be an AnimatedContainer; the width response never came from
      // that widget, so what this measures is unchanged.
      double widthOf(String label) => tester
          .getSize(find
              .ancestor(
                of: find.text(label),
                matching: find.byType(Container),
              )
              .first)
          .width;

      final restingFirst = widthOf('One');
      final restingSecond = widthOf('Two');

      // Hold the first button down and let the spring travel.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('One')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(widthOf('One'), greaterThan(restingFirst));
      expect(widthOf('Two'), lessThan(restingSecond));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('M3EChip', () {
    testWidgets('shows label, icon and count badge', (tester) async {
      await tester.pumpWidget(wrap(const M3EChip(
        label: 'Priority',
        icon: Icons.flag,
        selected: true,
        count: 3,
      )));

      expect(find.text('Priority'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides the badge when the count is zero', (tester) async {
      await tester.pumpWidget(wrap(const M3EChip(label: 'State', count: 0)));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
          wrap(M3EChip(label: 'Tap me', onTap: () => tapped = true)));

      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('the corner morph is driven, not filtered', (tester) async {
      // The corner used to be computed by a spring and then handed to an
      // AnimatedContainer, whose own curve re-animated toward each value the
      // spring produced — a filter on top of the physics, flattening the
      // overshoot underneath it. Nothing between the spring and the box.
      double cornerOf() {
        final box = tester.widget<Container>(find
            .descendant(
              of: find.byType(M3EChip),
              matching: find.byType(Container),
            )
            .first);
        final decoration = box.decoration as BoxDecoration;
        return (decoration.borderRadius as BorderRadius).topLeft.x;
      }

      await tester.pumpWidget(wrap(const M3EChip(label: 'Filter')));
      final atRest = cornerOf();

      await tester
          .pumpWidget(wrap(const M3EChip(label: 'Filter', selected: true)));
      await tester.pump(const Duration(milliseconds: 16));
      final travelling = cornerOf();

      await tester.pumpAndSettle();
      final settled = cornerOf();

      expect(travelling, isNot(atRest),
          reason: 'the corner should be moving one frame in');
      expect(settled, lessThan(atRest),
          reason: 'a selected chip pulls its corners in');

      expect(
        find.descendant(
          of: find.byType(M3EChip),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
        reason: 'an implicit animation here would filter the spring',
      );
    });
  });

  group('M3ESplitButton', () {
    testWidgets('primary half fires its own action', (tester) async {
      var pressed = false;
      await tester.pumpWidget(wrap(M3ESplitButton(
        label: 'Create',
        icon: Icons.add,
        onPressed: () => pressed = true,
        options: const [],
      )));

      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('trailing half opens the menu', (tester) async {
      await tester.pumpWidget(wrap(M3ESplitButton(
        label: 'Create',
        onPressed: () {},
        options: [
          M3EMenuOption(label: 'From template', onSelected: () {}),
        ],
      )));

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.text('From template'), findsOneWidget);
    });
  });

  group('M3EFabMenu', () {
    testWidgets('expands to reveal labelled actions and runs one',
        (tester) async {
      var created = false;
      await tester.pumpWidget(wrap(M3EFabMenu(
        actions: [
          M3EFabAction(
            label: 'New issue',
            icon: Icons.edit_square,
            onPressed: () => created = true,
          ),
        ],
      )));

      expect(find.text('New issue'), findsNothing);

      await tester.tap(find.byType(M3EFabMenu));
      await tester.pumpAndSettle();
      expect(find.text('New issue'), findsOneWidget);

      await tester.tap(find.text('New issue'));
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(find.text('New issue'), findsNothing);
    });
  });

  group('M3EFlexibleHeaderScaffold', () {
    testWidgets('collapses the large title once content scrolls under it',
        (tester) async {
      // Under the app's own theme, not Material's defaults: the header now
      // takes its sizes from textTheme, and stock Material sizes headlineSmall
      // at 24 too — so a foreign theme makes the 24dp predicate ambiguous and
      // tests a widget the app never renders.
      await tester.pumpWidget(MaterialApp(
        theme: PlaneTheme.dark(),
        home: Scaffold(
          body: M3EFlexibleHeaderScaffold(
            title: 'My issues',
            body: ListView.builder(
              itemCount: 60,
              itemBuilder: (_, i) =>
                  SizedBox(height: 48, child: Text('row $i')),
            ),
          ),
        ),
      ));

      // The toolbar cross-fades between the brand mark and the inline title,
      // so both are always in the tree — collapse shows up as opacity.
      double brandOpacity() => tester
          .widget<Opacity>(find.ancestor(
            of: find.text('Plane'),
            matching: find.byType(Opacity),
          ))
          .opacity;

      // At rest: brand visible, large title at full size.
      expect(brandOpacity(), 1.0);
      final large = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == 'My issues' && w.style?.fontSize == 24,
        ),
      );
      expect(large.style?.fontWeight, FontWeight.w700);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Collapsed: the brand has handed the toolbar over to the inline title.
      expect(brandOpacity(), lessThan(0.05));
    });
  });

  group('M3EAppBar', () {
    testWidgets('renders title, subtitle and actions', (tester) async {
      var pressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: M3EAppBar(
            title: 'Plane Mobile',
            subtitle: 'PLM',
            actions: [
              M3EAppBarAction(
                icon: Icons.more_horiz,
                tooltip: 'More',
                onPressed: () => pressed = true,
              ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ));

      expect(find.text('Plane Mobile'), findsOneWidget);
      expect(find.text('PLM'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('shows a back button only when the route can pop',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: M3EAppBar(title: 'Root'),
          body: SizedBox.shrink(),
        ),
      ));
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // Push a second route; that one can pop, so it gets the back affordance.
      final context = tester.element(find.byType(Scaffold));
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const Scaffold(
          appBar: M3EAppBar(title: 'Pushed'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pushed'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('reserves height for a bottom slot', (tester) async {
      const bar = M3EAppBar(title: 'X');
      const withBottom = M3EAppBar(
        title: 'X',
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: SizedBox(height: 48),
        ),
      );
      expect(withBottom.preferredSize.height - bar.preferredSize.height, 48);
    });

    testWidgets('preferredSize accounts for the divider, so it never overflows',
        (tester) async {
      // Regression: the divider lives in the same Column as the toolbar row.
      // Leaving it out of preferredSize made Scaffold under-allocate and the
      // bar overflowed by exactly the divider's height.
      const withDivider = M3EAppBar(title: 'X');
      const without = M3EAppBar(title: 'X', showDivider: false);
      expect(withDivider.preferredSize.height,
          greaterThan(without.preferredSize.height));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(appBar: withDivider, body: SizedBox.shrink()),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('M3ELoadingIndicator', () {
    testWidgets('keeps animating without settling', (tester) async {
      await tester.pumpWidget(wrap(const M3ELoadingIndicator()));
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('M3ECookieShape', () {
    test('a zero-lobe shape is a circle of the requested size', () {
      const shape = M3ECookieShape(lobes: 0, amplitude: 0);
      final bounds = shape.toPath(const Size(100, 100)).getBounds();
      expect(bounds.width, closeTo(100, 1.5));
      expect(bounds.height, closeTo(100, 1.5));
    });

    test('a lobed shape stays inside its box', () {
      const shape = M3ECookieShape(lobes: 7, amplitude: 0.2);
      final bounds = shape.toPath(const Size(100, 100)).getBounds();
      expect(bounds.width, lessThanOrEqualTo(100.5));
    });
  });

  group('reduced motion', () {
    // Every moving thing in this app is a spring, so a user who asks the system
    // for less motion must actually get less — otherwise the whole design
    // language ignores an accessibility setting.
    testWidgets('M3ESpringBuilder snaps instead of animating', (tester) async {
      late double observed;
      Widget build(double target) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: M3ESpringBuilder(
                value: target,
                spring: M3EMotion.defaultSpatial,
                builder: (_, v, __) {
                  observed = v;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump();
      // No settling: the value is already there on the very next frame.
      expect(observed, 1.0);
    });

    testWidgets('springs still animate when motion is allowed', (tester) async {
      late double observed;
      Widget build(double target) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(),
              child: M3ESpringBuilder(
                value: target,
                spring: M3EMotion.defaultSpatial,
                builder: (_, v, __) {
                  observed = v;
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 16));
      expect(observed, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(observed, closeTo(1, 0.02));
    });
  });

  group('M3ENative', () {
    // The Compose-backed views come from material3:1.5.0-alpha24 and can only
    // render on Android. Under `flutter test` there is no platform view
    // registry, so the widgets must fall back to the Dart implementations —
    // if they did not, every test touching them would render a blank box.
    testWidgets('button group falls back to the Dart implementation',
        (tester) async {
      expect(M3ENative.isAvailable, isFalse);

      await tester.pumpWidget(wrap(SizedBox(
        width: 320,
        child: M3ENativeButtonGroup(
          labels: const ['List', 'Board', 'Table'],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      )));

      expect(find.byType(M3EButtonGroup), findsOneWidget);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.text('Board'), findsOneWidget);
    });

    testWidgets('fallback still reports selection', (tester) async {
      int? selected;
      await tester.pumpWidget(wrap(SizedBox(
        width: 320,
        child: M3ENativeButtonGroup(
          labels: const ['List', 'Board'],
          selectedIndex: 0,
          onSelected: (i) => selected = i,
        ),
      )));

      await tester.tap(find.text('Board'));
      await tester.pump();
      expect(selected, 1);
    });

    testWidgets('loading indicator falls back to the Dart implementation',
        (tester) async {
      await tester.pumpWidget(wrap(const M3ENativeLoadingIndicator(size: 32)));
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      expect(find.byType(AndroidView), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('M3ESpringBuilder', () {
    testWidgets('drives its value toward the new target', (tester) async {
      late double observed;
      Widget build(double target) => wrap(M3ESpringBuilder(
            value: target,
            spring: M3EMotion.defaultSpatial,
            builder: (_, v, __) {
              observed = v;
              return const SizedBox.shrink();
            },
          ));

      await tester.pumpWidget(build(0));
      expect(observed, 0);

      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(observed, greaterThan(0));

      await tester.pumpAndSettle();
      expect(observed, closeTo(1, 0.02));
    });
  });

  group('M3ETextField', () {
    // tool/adb_drive.py cannot see this. The platform carries a text field's
    // accessible name in AccessibilityNodeInfo.hintText, which
    // `uiautomator dump` does not print, so on-device the field reads as
    // anonymous whether or not it is named. The semantics tree is readable
    // here, so this is where the guarantee is pinned.
    testWidgets(
        'publishes its label even in compact mode, where nothing '
        'renders it visually', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const M3ETextField(
        label: 'Search projects',
        hint: 'Search projects...',
        compact: true,
        prefixIcon: Icons.search,
      )));

      expect(
        tester.getSemantics(find.byType(TextField)).label,
        contains('Search projects'),
        reason: 'compact mode drops the visible label, so the semantics '
            'label is the only name the field has',
      );
      handle.dispose();
    });

    // The label has to outlive the hint: Android drops a placeholder from the
    // accessible name as soon as the field holds content, which is exactly
    // when a screen reader most needs to say what the field is.
    testWidgets('keeps its label once the field has content', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      await tester.pumpWidget(wrap(M3ETextField(
        label: 'Search projects',
        hint: 'Search projects...',
        compact: true,
        controller: controller,
      )));

      await tester.enterText(find.byType(TextField), 'plane');
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(TextField)).label,
        contains('Search projects'),
      );
      handle.dispose();
    });
  });
}
