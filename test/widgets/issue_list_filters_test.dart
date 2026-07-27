import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/screens/issues/issue_list_screen.dart';
import 'package:plane_mobile/widgets/filter_bar.dart';

import '../test_helpers.dart';
import 'issue_display_options_test.dart' show chooseGrouping, iconButton;

/// The filter bar, which had no call site anywhere in the app.
///
/// `_filterState` was declared, never assigned and read three times: the
/// "No issues match filters" branch could not be reached, and `_saveAsView` —
/// the only code in the app that creates a view — had no caller.

final _states = {
  'todo': makeState(id: 'todo', name: 'Todo', group: 'unstarted'),
  'doing': makeState(id: 'doing', name: 'In Progress', group: 'started'),
};

final _issues = [
  makeIssue(id: 'i1', name: 'Urgent one', state: 'todo', priority: 'urgent'),
  makeIssue(id: 'i2', name: 'Low one', state: 'doing', priority: 'low'),
];

Widget wrap() => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: IssueListScreen(
            workspaceSlug: 'acme',
            projectId: 'p1',
            projectIdentifier: 'PLM',
            issues: _issues,
            states: _states,
            labels: const [],
            members: const [],
            onRefresh: () async {},
          ),
        ),
      ),
    );

/// Opens the priority filter, ticks [priority] and confirms.
Future<void> filterByPriority(WidgetTester tester, String priority) async {
  // The bar's group chip shows the current grouping, which can also read
  // "Priority". The filter chips come first in the bar.
  await tester.tap(find.text('Priority').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(priority));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the live listing carries a filter bar', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(FilterBar), findsOneWidget);
  });

  testWidgets('filtering narrows the list and says so when nothing is left',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Urgent one'), findsOneWidget);
    expect(find.text('Low one'), findsOneWidget);

    await filterByPriority(tester, 'Urgent');
    expect(find.text('Urgent one'), findsOneWidget);
    expect(find.text('Low one'), findsNothing);

    // The empty branch that could never be reached before.
    await filterByPriority(tester, 'Urgent'); // untick
    await filterByPriority(tester, 'Medium');
    expect(find.text('No work items match these filters'), findsOneWidget);
  });

  testWidgets('clearing the filters keeps the grouping the sheet chose',
      (tester) async {
    // The bar scrolls horizontally and "Clear" is its last chip, past the end
    // of an 800dp surface — off-screen children of a lazy list are not built,
    // so it cannot be tapped without the room.
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(iconButton('Display options'));
    await tester.pumpAndSettle();
    await chooseGrouping(tester, 'Priority');
    expect(find.text('URGENT'), findsOneWidget);

    await filterByPriority(tester, 'Urgent');
    expect(find.text('Low one'), findsNothing);

    // "Clear" hands back a default FilterState, whose grouping is "state".
    // Adopting that blindly would throw away the choice made above.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Low one'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('TODO'), findsNothing);
  });

  testWidgets('the sort chip still changes the ordering', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The bar and the display sheet show one setting between them, so what the
    // bar changes has to reach the sheet.
    await tester.tap(find.text('Created'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updated at'));
    await tester.pumpAndSettle();

    expect(find.text('Updated'), findsOneWidget);

    await tester.tap(iconButton('Display options'));
    await tester.pumpAndSettle();
    // Two now: the bar's chip behind the sheet and the sheet's own Ordering
    // row. One setting, shown in both places — which is the point.
    expect(find.text('Updated'), findsNWidgets(2));
  });
}
