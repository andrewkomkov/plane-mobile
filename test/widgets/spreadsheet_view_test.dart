import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/screens/issues/spreadsheet_view.dart';

import '../test_helpers.dart';

/// The table, held to being a table.
///
/// Every row and the header each owned a `SingleChildScrollView`, so dragging
/// one row sideways moved that row alone: the header stayed where it was, the
/// row below stayed where it was, and a column's cells stopped lining up with
/// their heading. Nothing about it was a table except the column widths.

Widget wrap() => MaterialApp(
      home: Scaffold(
        body: SpreadsheetView(
          workspaceSlug: 'ws',
          projectId: 'p1',
          projectIdentifier: 'PLM',
          issues: [
            makeIssue(id: 'i1', name: 'First', sequenceId: 1),
            makeIssue(id: 'i2', name: 'Second', sequenceId: 2),
          ],
          states: {'state-1': makeState(name: 'In Progress')},
          onRefresh: () {},
        ),
      ),
    );

/// Left edge of the widget carrying [text], in global coordinates.
double leftOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dx;

void main() {
  testWidgets('the header and every row scroll as one', (tester) async {
    // The table is 730 wide and the default test surface is 800, which fits
    // all of it — there would be nothing to scroll and the assertions below
    // would pass against a table that still scrolled row by row.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap());
    await tester.pump();

    const columns = ['Due Date', 'First', 'Second'];
    final before = {for (final c in columns) c: leftOf(tester, c)};

    // Drag one data row. The header above it and the row below it have to
    // travel exactly as far.
    await tester.drag(find.text('First'), const Offset(-120, 0));
    await tester.pumpAndSettle();

    final moved = {for (final c in columns) c: before[c]! - leftOf(tester, c)};
    expect(moved['First'], greaterThan(50),
        reason: 'the row that was dragged did not scroll at all');
    for (final c in columns) {
      expect(moved[c], closeTo(moved['First']!, 0.5),
          reason: '$c did not travel with the row that was dragged');
    }
  });

  testWidgets('one horizontal scrollable, not one per row', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    final horizontal = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(horizontal, findsOneWidget);
  });

  testWidgets('an empty table says so instead of drawing a bare header',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpreadsheetView(
          workspaceSlug: 'ws',
          projectId: 'p1',
          projectIdentifier: 'PLM',
          issues: const [],
          states: const {},
          onRefresh: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('No work items'), findsOneWidget);
    expect(find.text('Due Date'), findsNothing);
  });
}
