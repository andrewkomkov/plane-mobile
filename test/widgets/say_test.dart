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

  testWidgets('a removal offers the way back', (tester) async {
    var undone = 0;
    await pumpAndTap(
        tester, (context) => sayUndo(context, 'Removed', () => undone++));

    expect(find.text('Removed'), findsOneWidget);
    // The action is not tappable until the snackbar has finished sliding in.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, 1);
  });

  testWidgets('the undo is up long enough to be noticed and reached',
      (tester) async {
    await pumpAndTap(tester, (context) => sayUndo(context, 'Removed', () {}));

    // Material's four-second default is the length of a message; this one is
    // the length of a decision, and the user it exists for has to notice the
    // snackbar first.
    expect(snackBar(tester).duration.inSeconds, greaterThan(4));
  });

  testWidgets('the action label is legible on the app surface', (tester) async {
    // The snackbar sits on the app's own surface ramp, not Material's inverse
    // one, so `inversePrimary` — the default action colour — is the wrong end
    // of the ramp and lands close to invisible.
    final theme = PlaneTheme.dark();
    expect(theme.snackBarTheme.actionTextColor, theme.colorScheme.primary);
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
