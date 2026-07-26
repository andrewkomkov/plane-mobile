import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/issue.dart';
import 'package:plane_mobile/models/label.dart';
import 'package:plane_mobile/models/member.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/models/state.dart';
import 'package:plane_mobile/providers/data_providers.dart';
import 'package:plane_mobile/screens/home/my_issues_tab.dart';
import 'package:plane_mobile/screens/issues/issue_list_screen.dart';
import 'package:plane_mobile/widgets/m3e/icon_button.dart';

import '../test_helpers.dart';

/// The "Grouping" row of the display sheet, held to actually grouping.
///
/// My issues called `groupIssuesByStateGroup` unconditionally, so the row
/// cycled through Priority, Assignee and Label and changed nothing but its own
/// caption — a setting that did nothing, on the screen a user opens first.

final _states = {
  'todo': makeState(id: 'todo', name: 'Todo', group: 'unstarted'),
  'doing': makeState(id: 'doing', name: 'In Progress', group: 'started'),
};

final _issues = [
  makeIssue(
      id: 'i1',
      name: 'Urgent one',
      state: 'todo',
      priority: 'urgent',
      project: 'p1'),
  makeIssue(
      id: 'i2',
      name: 'Low one',
      state: 'doing',
      priority: 'low',
      project: 'p1'),
];

class _StubCache extends DataCache {
  @override
  Future<void> loadProjects(String ws, {bool force = false}) async {}

  @override
  List<Project>? getProjects(String ws) => [
        Project(
          id: 'p1',
          name: 'Plane',
          identifier: 'PLM',
          network: 0,
          totalMembers: 1,
          isMember: true,
          createdAt: DateTime(2026),
        ),
      ];

  @override
  Future<void> loadProjectCoreData(String ws, String pid) async {}

  @override
  Future<void> loadProjectExtras(String ws, String pid) async {}

  @override
  Map<String, IssueState>? getStates(String ws, String pid) => _states;

  @override
  List<Issue>? getIssues(String ws, String pid) => _issues;

  @override
  List<Label>? getLabels(String ws, String pid) => const [];

  @override
  List<Member>? getMembers(String ws, String pid) => const [];
}

/// The icon buttons carry their name as a semantic label rather than as a
/// `Tooltip` widget, so `find.byTooltip` finds nothing.
Finder iconButton(String tooltip) =>
    find.byWidgetPredicate((w) => w is M3EIconButton && w.tooltip == tooltip);

/// Taps the "Grouping" row of the open display sheet [times] times, then
/// dismisses it. The row cycles state → priority → assignee → label.
Future<void> cycleGrouping(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text('Grouping'));
    await tester.pumpAndSettle();
  }
  Navigator.of(tester.element(find.text('Grouping'))).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('My issues groups by whatever the display sheet says',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dataCacheProvider.overrideWithValue(_StubCache())],
      child: const MaterialApp(
        home: MyIssuesTab(workspaceSlug: 'acme', currentUserId: null),
      ),
    ));
    await tester.pumpAndSettle();

    // Scope defaults to "Assigned", which nothing here is. "All" is the scope
    // that shows the two work items.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Grouped by state to begin with, as the sheet's default says.
    expect(find.text('TODO'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);

    await tester.tap(iconButton('Open list options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Display options'));
    await tester.pumpAndSettle();
    await cycleGrouping(tester, 1);

    // The headers are the priorities now, and the state groups are gone.
    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('TODO'), findsNothing);
    expect(find.text('IN PROGRESS'), findsNothing);
  });

  testWidgets('the project issue list groups by the same setting',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
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
    ));
    await tester.pumpAndSettle();

    expect(find.text('TODO'), findsOneWidget);

    await tester.tap(iconButton('Display options'));
    await tester.pumpAndSettle();
    await cycleGrouping(tester, 1);

    expect(find.text('URGENT'), findsOneWidget);
    expect(find.text('TODO'), findsNothing);
  });
}
