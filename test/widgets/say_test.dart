import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/utils/say.dart';

void main() {
  Future<void> pumpAndTap(
    WidgetTester tester,
    void Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: PlaneTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => action(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  SnackBar snackBar(WidgetTester tester) =>
      tester.widget<SnackBar>(find.byType(SnackBar));

  testWidgets('a plain message keeps the themed surface', (tester) async {
    await pumpAndTap(tester, (context) => say(context, 'View saved'));

    expect(find.text('View saved'), findsOneWidget);
    expect(snackBar(tester).backgroundColor, isNull,
        reason: 'null means snackBarTheme decides');
  });

  testWidgets('a failure is a different object, not a different sentence',
      (tester) async {
    // "View saved" and "Failed to restore cycle: DioException…" rendered
    // identically before this: same surface, no icon, no border.
    await pumpAndTap(
        tester, (context) => sayError(context, 'Failed to restore cycle'));

    expect(find.text('Failed to restore cycle'), findsOneWidget);
    expect(snackBar(tester).backgroundColor,
        PlaneTheme.dark().colorScheme.errorContainer);
    expect(find.byIcon(Icons.error_outline), findsOneWidget,
        reason: 'colour is not the only channel');
  });

  testWidgets('a second message replaces the first', (tester) async {
    var n = 0;
    await pumpAndTap(tester, (context) => say(context, 'Message ${++n}'));
    expect(find.text('Message 1'), findsOneWidget);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // Not queued behind it: a user who taps three rows should see the third
    // answer rather than wait for it.
    expect(find.text('Message 1'), findsNothing);
    expect(find.text('Message 2'), findsOneWidget);
  });
}
