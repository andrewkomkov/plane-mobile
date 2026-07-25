import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/property_chip.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
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

    testWidgets('a tappable chip stays as narrow as its content', (tester) async {
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
