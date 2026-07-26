import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/m3e/shapes.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/widgets/property_chip.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  /// The chip's own decorated box. There is exactly one Container in the
  /// subtree — the pill itself — so this cannot pick up the hit-target
  /// padding around it.
  BoxDecoration decorationOf(WidgetTester tester, Finder chip) {
    final container = tester.widget<Container>(
      find.descendant(of: chip, matching: find.byType(Container)),
    );
    return container.decoration! as BoxDecoration;
  }

  double cornerOf(BoxDecoration decoration) =>
      (decoration.borderRadius! as BorderRadius).topLeft.x;

  Color labelColourOf(WidgetTester tester, Finder chip, String label) {
    final text = tester.widget<Text>(
      find.descendant(of: chip, matching: find.text(label)),
    );
    return text.style!.color!;
  }

  group('PropertyChip', () {
    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const PropertyChip(
          icon: Icons.flag,
          iconColor: Colors.red,
          label: 'High',
        ),
      ));

      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const PropertyChip(
          icon: Icons.flag,
          iconColor: Colors.red,
          label: 'High',
        ),
      ));

      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWidget(
        PropertyChip(
          icon: Icons.flag,
          iconColor: Colors.red,
          label: 'High',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(PropertyChip));
      expect(tapped, isTrue);
    });

    testWidgets('a tappable chip stays as narrow as its content',
        (tester) async {
      // The 48dp hit target is vertical padding, not a full-width row. A chip
      // that claims the whole width forces one chip per line in the property
      // Wrap it lives in, which is how the issue detail screen ended up with
      // its pills stacked down the middle of the screen.
      await tester.pumpWidget(wrapWidget(
        SizedBox(
          width: 400,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PropertyChip(
                icon: Icons.flag,
                iconColor: Colors.red,
                label: 'High',
                onTap: () {},
              ),
              PropertyChip(
                icon: Icons.person_outline,
                iconColor: Colors.blue,
                label: 'Assignee',
                onTap: () {},
              ),
            ],
          ),
        ),
      ));

      final first = tester.getRect(find.byType(PropertyChip).first);
      final second = tester.getRect(find.byType(PropertyChip).last);

      expect(first.width, lessThan(200),
          reason: 'chip should size to its label, not to the container');
      expect(first.height, 48);
      expect(second.top, first.top,
          reason: 'two chips this narrow must share one row of the Wrap');
    });

    testWidgets('a set chip and an unset one do not render the same',
        (tester) async {
      // The whole point of hasValue. Before it, "Done" and "Assignee" were
      // byte-identical hollow outlines, so a value and an absence carried the
      // same weight in a row that mixes both. Two channels are asserted here,
      // fill and corner radius, because either one alone can be lost — to a
      // colour-blind user, or to a theme with a flatter surface ramp.
      await tester.pumpWidget(wrapWidget(
        Wrap(
          children: [
            PropertyChip(
              key: const Key('set'),
              icon: Icons.flag,
              iconColor: Colors.red,
              label: 'High',
              hasValue: true,
              onTap: () {},
            ),
            PropertyChip(
              key: const Key('unset'),
              icon: Icons.person_outline,
              iconColor: Colors.grey,
              label: 'Assignee',
              hasValue: false,
              onTap: () {},
            ),
          ],
        ),
      ));

      final set = decorationOf(tester, find.byKey(const Key('set')));
      final unset = decorationOf(tester, find.byKey(const Key('unset')));

      expect(set.color!.a, greaterThan(0),
          reason: 'a chip holding a value is filled');
      expect(unset.color!.a, 0, reason: 'an empty placeholder is hollow');
      expect(cornerOf(set), lessThan(cornerOf(unset)),
          reason: 'a chip holding a value pulls its corners in');

      expect(
        labelColourOf(tester, find.byKey(const Key('set')), 'High'),
        isNot(
            labelColourOf(tester, find.byKey(const Key('unset')), 'Assignee')),
      );
    });

    testWidgets('the set/unset fill is visible against both themes',
        (tester) async {
      // The repo has shipped a light palette where a container role and the
      // page behind it were the same colour, which would silently reduce the
      // distinction above to the corner radius alone.
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: PropertyChip(
              icon: Icons.flag,
              iconColor: Colors.red,
              label: 'High',
              hasValue: true,
            ),
          ),
        ));

        final fill = decorationOf(tester, find.byType(PropertyChip)).color!;
        expect(fill, isNot(theme.colorScheme.surface));
        expect(fill, isNot(theme.scaffoldBackgroundColor));
      }
    });

    testWidgets('leaving hasValue out renders exactly as it always did',
        (tester) async {
      // property_chip is shared with the spreadsheet table, the module list
      // and the cycle and module detail screens, none of which have a
      // set/unset contrast to draw. They stay on the default, and the default
      // must therefore stay put: hollow, at the small corner, speaking at full
      // strength.
      await tester.pumpWidget(MaterialApp(
        theme: PlaneTheme.light(),
        home: const Scaffold(
          body: PropertyChip(
            icon: Icons.circle,
            iconColor: Colors.green,
            label: 'In progress',
          ),
        ),
      ));

      final decoration = decorationOf(tester, find.byType(PropertyChip));
      expect(decoration.color!.a, 0);
      expect(cornerOf(decoration), M3EShape.small);
      expect(
        labelColourOf(tester, find.byType(PropertyChip), 'In progress'),
        PlaneTheme.light().colorScheme.onSurface,
      );
    });

    testWidgets('every state keeps the control-boundary outline',
        (tester) async {
      // WCAG 1.4.11 wants 3:1 of the boundary identifying a control, and
      // outlineVariant is 1.32:1 on the light background. Dimming the unset
      // chip's border would have been the obvious way to separate it from a
      // set one; the fill and the corner do that job instead precisely so the
      // outline can stay.
      final scheme = PlaneTheme.light().colorScheme;
      for (final hasValue in [null, true, false]) {
        await tester.pumpWidget(MaterialApp(
          theme: PlaneTheme.light(),
          home: Scaffold(
            body: PropertyChip(
              icon: Icons.flag,
              iconColor: Colors.red,
              label: 'Due',
              hasValue: hasValue,
            ),
          ),
        ));

        final border =
            decorationOf(tester, find.byType(PropertyChip)).border! as Border;
        expect(border.top.color, scheme.outline, reason: 'hasValue $hasValue');
      }
    });

    testWidgets('does not crash when onTap is null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const PropertyChip(
          icon: Icons.flag,
          iconColor: Colors.red,
          label: 'None',
          onTap: null,
        ),
      ));

      // Tapping should not throw
      await tester.tap(find.byType(PropertyChip));
    });
  });
}
