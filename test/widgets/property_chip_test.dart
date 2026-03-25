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
