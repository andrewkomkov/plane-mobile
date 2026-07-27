import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/app_navbar.dart';

void main() {
  const items = [
    NavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view,
        label: 'Projects'),
    NavItem(
        icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'Inbox'),
  ];

  /// A screen with the bar where the app puts it, and the reported height
  /// captured from the body — where a list that has to clear the bar asks.
  Future<double> reportedHeight(
    WidgetTester tester, {
    double bottomInset = 0,
    double textScale = 1.0,
  }) async {
    late double reported;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          extendBody: true,
          // Nested, because the project tabs are: a list screen builds its own
          // Scaffold inside the body of the one that carries the bar, and the
          // answer has to survive that.
          body: Scaffold(
            body: Builder(
              builder: (context) {
                reported = appNavBarHeight(context);
                return const SizedBox.expand();
              },
            ),
          ),
          bottomNavigationBar: AppNavBar(
            items: items,
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    ));
    return reported;
  }

  group('appNavBarHeight', () {
    testWidgets('is what the bar actually occupies', (tester) async {
      // The point of exporting it: six screens were padding their lists by a
      // literal, and a literal cannot be wrong here.
      final reported = await reportedHeight(tester);
      expect(tester.getSize(find.byType(AppNavBar)).height, reported);
    });

    testWidgets('counts the gesture inset under the bar', (tester) async {
      final flat = await reportedHeight(tester);
      final notched = await reportedHeight(tester, bottomInset: 34);
      expect(notched, flat + 34);
      expect(tester.getSize(find.byType(AppNavBar)).height, notched);
    });

    testWidgets('grows with the text scale, as the bar does', (tester) async {
      // The bar grows to fit its own label rather than clamping it, so a
      // constant would be short by exactly that growth at large text sizes.
      final normal = await reportedHeight(tester);
      final large = await reportedHeight(tester, textScale: 2.0);
      expect(large, greaterThan(normal));
      expect(tester.getSize(find.byType(AppNavBar)).height, large);
    });

    testWidgets('clearance leaves room above the glass', (tester) async {
      late double height;
      late double clearance;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          height = appNavBarHeight(context);
          clearance = appNavBarClearance(context);
          return const SizedBox.expand();
        }),
      ));
      expect(clearance, greaterThan(height));
    });
  });
}
