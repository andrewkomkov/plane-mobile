import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/confirm_dialog.dart';

void main() {
  /// Pumps a button that opens [open] and records what it answered.
  Future<List<bool>> run(
    WidgetTester tester,
    Future<bool> Function(BuildContext context) open,
  ) async {
    final answers = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  Color confirmColour(WidgetTester tester, String label) {
    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
    );
    final context = tester.element(find.text(label));
    return button.style?.foregroundColor?.resolve(const <WidgetState>{}) ??
        Theme.of(context)
            .textButtonTheme
            .style
            ?.foregroundColor
            ?.resolve(const <WidgetState>{}) ??
        Theme.of(context).colorScheme.primary;
  }

  group('confirmDestructive', () {
    testWidgets('paints the confirming action in the error role',
        (tester) async {
      await run(
        tester,
        (context) => confirmDestructive(
          context,
          title: 'Delete page',
          message: 'This cannot be undone',
          confirmLabel: 'Delete',
        ),
      );

      final error =
          Theme.of(tester.element(find.text('Delete'))).colorScheme.error;
      expect(confirmColour(tester, 'Delete'), error);
    });
  });

  group('confirmAction', () {
    testWidgets('does not paint a restore as a destruction', (tester) async {
      await run(
        tester,
        (context) => confirmAction(
          context,
          title: 'Restore cycle',
          message: 'Move it back into the active cycles?',
          confirmLabel: 'Restore',
        ),
      );

      final error =
          Theme.of(tester.element(find.text('Restore'))).colorScheme.error;
      expect(confirmColour(tester, 'Restore'), isNot(error));
      // And it looks like the button beside it, rather than inventing a role.
      expect(confirmColour(tester, 'Restore'), confirmColour(tester, 'Cancel'));
    });

    testWidgets('confirming answers true', (tester) async {
      final answers = await run(
        tester,
        (context) => confirmAction(
          context,
          title: 'Restore cycle',
          message: 'Move it back?',
          confirmLabel: 'Restore',
        ),
      );

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('a dismissed dialog is not a confirmation', (tester) async {
      final answers = await run(
        tester,
        (context) => confirmAction(
          context,
          title: 'Restore cycle',
          message: 'Move it back?',
          confirmLabel: 'Restore',
        ),
      );

      // A barrier tap, which is neither of the two buttons.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });
  });
}
