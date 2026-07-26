import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/issue_listing_switcher.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
      );

  group('IssueListingSwitcher', () {
    testWidgets('offers all three listings at once', (tester) async {
      await tester.pumpWidget(wrap(
        IssueListingSwitcher(value: IssueListing.live, onChanged: (_) {}),
      ));

      expect(find.text('Work items'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('reports which one is showing', (tester) async {
      // One selection, three positions. A screen reader and `adb_drive.py`
      // both read the state off the node, not off the fill colour.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(
        IssueListingSwitcher(value: IssueListing.drafts, onChanged: (_) {}),
      ));

      expect(
        tester.getSemantics(find.text('Drafts')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Archive')),
        isSemantics(isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('hands back the listing that was tapped', (tester) async {
      IssueListing? received;
      await tester.pumpWidget(wrap(
        IssueListingSwitcher(
          value: IssueListing.live,
          onChanged: (v) => received = v,
        ),
      ));

      await tester.tap(find.text('Archive'));
      await tester.pump();
      expect(received, IssueListing.archived);

      await tester.tap(find.text('Drafts'));
      await tester.pump();
      expect(received, IssueListing.drafts);
    });

    testWidgets('holds its width when the selection moves', (tester) async {
      // The control sits under the finger that changes it; a group that
      // resized between listings would move the next target out from under it.
      await tester.pumpWidget(wrap(
        IssueListingSwitcher(value: IssueListing.live, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(IssueListingSwitcher));

      await tester.pumpWidget(wrap(
        IssueListingSwitcher(value: IssueListing.archived, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(IssueListingSwitcher)), before);
    });

    testWidgets('survives a width that cannot fit the three labels',
        (tester) async {
      // The Compose ButtonGroup takes the process down when its items overflow;
      // the Dart one shares out whatever width it is given. Pinning that here
      // because this control has the longest label set of any group in the app.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: IssueListingSwitcher(
                value: IssueListing.live,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Drafts'), findsOneWidget);
    });
  });

  group('IssueListing', () {
    test('names its contents for the empty states', () {
      expect(IssueListing.live.plural, 'work items');
      expect(IssueListing.drafts.plural, 'drafts');
      expect(IssueListing.archived.plural, 'archived work items');
    });
  });

  group('draftSavedLabel', () {
    test('is absolute, because a draft is a thing you come back to', () {
      expect(
        draftSavedLabel(DateTime(2025, 3, 4, 10)),
        'Draft, saved 04.03.2025',
      );
    });

    test('pads a single-digit day and month', () {
      expect(draftSavedLabel(DateTime(2025, 1, 2)), 'Draft, saved 02.01.2025');
    });

    test('degrades to the bare word when there is no timestamp', () {
      expect(draftSavedLabel(null), 'Draft');
    });
  });
}
