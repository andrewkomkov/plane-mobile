import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/archive_toggle.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ArchiveToggle', () {
    testWidgets('reads the same on every list it appears on', (tester) async {
      await tester.pumpWidget(wrap(
        ArchiveToggle(
          showArchived: false,
          entityPlural: 'cycles',
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('names the list it belongs to, not just the word it draws',
        (tester) async {
      // The visible text is the bare word "Archived" on four different
      // screens. Automation and a screen reader need to know which one, and
      // what tapping will do.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(
        ArchiveToggle(
          showArchived: false,
          entityPlural: 'work items',
          onChanged: (_) {},
        ),
      ));

      expect(find.bySemanticsLabel('Show archived work items'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('says how to get back out once it is on', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(
        ArchiveToggle(
          showArchived: true,
          entityPlural: 'pages',
          onChanged: (_) {},
        ),
      ));

      expect(
        find.bySemanticsLabel('Showing archived pages, tap to show live pages'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('carries selected onto its semantics node', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(
        ArchiveToggle(
          showArchived: true,
          entityPlural: 'modules',
          onChanged: (_) {},
        ),
      ));

      expect(
        tester.getSemantics(find.bySemanticsLabel(
            'Showing archived modules, tap to show live modules')),
        isSemantics(isSelected: true, isButton: true),
      );
      handle.dispose();
    });

    testWidgets('flips the value it was given', (tester) async {
      bool? received;
      await tester.pumpWidget(wrap(
        ArchiveToggle(
          showArchived: false,
          entityPlural: 'cycles',
          onChanged: (v) => received = v,
        ),
      ));

      await tester.tap(find.text('Archived'));
      await tester.pump();

      expect(received, isTrue);
    });
  });

  group('archivedOnLabel', () {
    test('is absolute, because an archive is read months later', () {
      expect(
        archivedOnLabel(DateTime(2025, 3, 4, 10).toUtc()),
        'Archived 04.03.2025',
      );
    });

    test('pads a single-digit day and month', () {
      expect(archivedOnLabel(DateTime(2025, 1, 2)), 'Archived 02.01.2025');
    });

    test('degrades to the bare word when the server sent no timestamp', () {
      expect(archivedOnLabel(null), 'Archived');
    });
  });
}
