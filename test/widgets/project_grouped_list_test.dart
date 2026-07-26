import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/cycle.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/models/workspace_rollup.dart';
import 'package:plane_mobile/screens/workspace/project_grouped_list.dart';

Project makeProject({
  required String id,
  required String name,
  String identifier = 'ABC',
}) =>
    Project(
      id: id,
      name: name,
      identifier: identifier,
      network: 2,
      totalMembers: 1,
      isMember: true,
      createdAt: DateTime(2025, 1, 1),
    );

Cycle makeCycle(String name) => Cycle(
      id: name,
      name: name,
      totalIssues: 0,
      completedIssues: 0,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  group('ProjectGroupedList.group', () {
    test('drops rows whose project the caller is not in', () {
      // This is the client half of a server defect: WorkspaceCyclesEndpoint
      // and WorkspaceModulesEndpoint filter on workspace slug alone behind a
      // permission class that only checks workspace membership, so they return
      // cycles and modules out of projects the caller has no access to. Those
      // rows cannot be opened (the detail screens are project-scoped) and
      // cannot be named, so they are not shown.
      final groups = ProjectGroupedList.group<Cycle>(
        [
          ProjectScoped(item: makeCycle('mine'), projectId: 'p1'),
          ProjectScoped(item: makeCycle('theirs'), projectId: 'p-elsewhere'),
        ],
        {'p1': makeProject(id: 'p1', name: 'Mobile')},
      );

      expect(groups, hasLength(1));
      expect(groups.single.key.name, 'Mobile');
      expect(groups.single.value.map((c) => c.name), ['mine']);
    });

    test('drops a row with no project at all', () {
      final groups = ProjectGroupedList.group<Cycle>(
        [ProjectScoped(item: makeCycle('orphan'), projectId: null)],
        {'p1': makeProject(id: 'p1', name: 'Mobile')},
      );
      expect(groups, isEmpty);
    });

    test('orders groups by project name, case-insensitively', () {
      final groups = ProjectGroupedList.group<Cycle>(
        [
          ProjectScoped(item: makeCycle('a'), projectId: 'p2'),
          ProjectScoped(item: makeCycle('b'), projectId: 'p1'),
          ProjectScoped(item: makeCycle('c'), projectId: 'p3'),
        ],
        {
          'p1': makeProject(id: 'p1', name: 'zebra'),
          'p2': makeProject(id: 'p2', name: 'Apples'),
          'p3': makeProject(id: 'p3', name: 'mango'),
        },
      );

      expect(groups.map((g) => g.key.name), ['Apples', 'mango', 'zebra']);
    });

    test('keeps server order within a project', () {
      final groups = ProjectGroupedList.group<Cycle>(
        [
          ProjectScoped(item: makeCycle('newest'), projectId: 'p1'),
          ProjectScoped(item: makeCycle('older'), projectId: 'p1'),
        ],
        {'p1': makeProject(id: 'p1', name: 'Mobile')},
      );
      expect(groups.single.value.map((c) => c.name), ['newest', 'older']);
    });
  });

  group('ProjectGroupedList widget', () {
    testWidgets('draws one header per project and a row per item',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectGroupedList<Cycle>(
            items: [
              ProjectScoped(item: makeCycle('Sprint 1'), projectId: 'p1'),
              ProjectScoped(item: makeCycle('Sprint 2'), projectId: 'p1'),
              ProjectScoped(item: makeCycle('Sprint 9'), projectId: 'p2'),
            ],
            projects: {
              'p1': makeProject(id: 'p1', name: 'Mobile'),
              'p2': makeProject(id: 'p2', name: 'Web'),
            },
            emptyState: const Text('nothing'),
            rowBuilder: (ctx, project, cycle) =>
                Text('${project.identifier} ${cycle.name}'),
          ),
        ),
      ));

      // SectionHeader uppercases its label.
      expect(find.text('MOBILE'), findsOneWidget);
      expect(find.text('WEB'), findsOneWidget);
      expect(find.text('ABC Sprint 1'), findsOneWidget);
      expect(find.text('ABC Sprint 9'), findsOneWidget);
      expect(find.text('nothing'), findsNothing);
    });

    testWidgets('shows the empty state when everything was filtered out',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectGroupedList<Cycle>(
            items: [
              ProjectScoped(item: makeCycle('hidden'), projectId: 'p-elsewhere')
            ],
            projects: {'p1': makeProject(id: 'p1', name: 'Mobile')},
            emptyState: const Text('nothing'),
            rowBuilder: (ctx, project, cycle) => Text(cycle.name),
          ),
        ),
      ));

      expect(find.text('nothing'), findsOneWidget);
      expect(find.text('hidden'), findsNothing);
    });
  });
}
