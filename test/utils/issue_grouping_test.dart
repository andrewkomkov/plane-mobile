import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/utils/issue_grouping.dart';
import 'package:plane_mobile/widgets/filter_bar.dart';
import '../test_helpers.dart';

void main() {
  group('groupIssuesByStateGroup', () {
    final states = {
      's1': makeState(id: 's1', group: 'started'),
      's2': makeState(id: 's2', group: 'backlog'),
      's3': makeState(id: 's3', group: 'completed'),
    };

    test('groups issues by their state group', () {
      final issues = [
        makeIssue(id: 'i1', state: 's1'),
        makeIssue(id: 'i2', state: 's2'),
        makeIssue(id: 'i3', state: 's1'),
      ];
      final groups = groupIssuesByStateGroup(issues, states);

      expect(groups['started']!.length, 2);
      expect(groups['backlog']!.length, 1);
      expect(groups.containsKey('completed'), isFalse); // empty groups removed
    });

    test('defaults to backlog for unknown state', () {
      final issues = [makeIssue(id: 'i1', state: 'unknown-state')];
      final groups = groupIssuesByStateGroup(issues, states);

      expect(groups['backlog']!.length, 1);
    });

    test('excludes completed and cancelled when excludeDone is true', () {
      final issues = [
        makeIssue(id: 'i1', state: 's1'),
        makeIssue(id: 'i2', state: 's3'),
      ];
      final groups = groupIssuesByStateGroup(issues, states, excludeDone: true);

      expect(groups.containsKey('completed'), isFalse);
      expect(groups['started']!.length, 1);
    });

    test('returns empty map for empty issue list', () {
      final groups = groupIssuesByStateGroup([], states);
      expect(groups, isEmpty);
    });
  });

  group('groupIssuesByPriority', () {
    test('groups issues by priority', () {
      final issues = [
        makeIssue(id: 'i1', priority: 'high'),
        makeIssue(id: 'i2', priority: 'high'),
        makeIssue(id: 'i3', priority: 'low'),
      ];
      final groups = groupIssuesByPriority(issues);

      expect(groups['high']!.length, 2);
      expect(groups['low']!.length, 1);
    });

    test('empty groups are removed', () {
      final issues = [makeIssue(priority: 'urgent')];
      final groups = groupIssuesByPriority(issues);

      expect(groups.keys, ['urgent']);
    });
  });

  group('groupIssuesByAssignee', () {
    final members = [
      makeMember(id: 'm1', displayName: 'Alice'),
      makeMember(id: 'm2', displayName: 'Bob'),
    ];

    test('groups by assignee name', () {
      final issues = [
        makeIssue(id: 'i1', assignees: ['m1']),
        makeIssue(id: 'i2', assignees: ['m2']),
      ];
      final groups = groupIssuesByAssignee(issues, members);

      expect(groups['Alice']!.length, 1);
      expect(groups['Bob']!.length, 1);
    });

    test('puts unassigned issues in Unassigned group', () {
      final issues = [makeIssue(id: 'i1', assignees: [])];
      final groups = groupIssuesByAssignee(issues, members);

      expect(groups['Unassigned']!.length, 1);
    });

    test('issue with multiple assignees appears in each group', () {
      final issues = [
        makeIssue(id: 'i1', assignees: ['m1', 'm2'])
      ];
      final groups = groupIssuesByAssignee(issues, members);

      expect(groups['Alice']!.length, 1);
      expect(groups['Bob']!.length, 1);
    });

    test('unknown assignee maps to Unknown', () {
      final issues = [
        makeIssue(id: 'i1', assignees: ['unknown-id'])
      ];
      final groups = groupIssuesByAssignee(issues, members);

      expect(groups['Unknown']!.length, 1);
    });
  });

  group('groupIssuesByLabel', () {
    final labels = [
      makeLabel(id: 'l1', name: 'Bug'),
      makeLabel(id: 'l2', name: 'Feature'),
    ];

    test('groups by label name', () {
      final issues = [
        makeIssue(id: 'i1', labels: ['l1']),
        makeIssue(id: 'i2', labels: ['l2']),
      ];
      final groups = groupIssuesByLabel(issues, labels);

      expect(groups['Bug']!.length, 1);
      expect(groups['Feature']!.length, 1);
    });

    test('puts unlabeled issues in No label group', () {
      final issues = [makeIssue(id: 'i1', labels: [])];
      final groups = groupIssuesByLabel(issues, labels);

      expect(groups['No label']!.length, 1);
    });
  });

  group('applyFilters', () {
    test('filters by state', () {
      final issues = [
        makeIssue(id: 'i1', state: 's1'),
        makeIssue(id: 'i2', state: 's2'),
      ];
      final filtered = applyFilters(
        issues,
        const FilterState(selectedStates: {'s1'}),
      );
      expect(filtered.length, 1);
      expect(filtered[0].id, 'i1');
    });

    test('filters by priority', () {
      final issues = [
        makeIssue(id: 'i1', priority: 'high'),
        makeIssue(id: 'i2', priority: 'low'),
      ];
      final filtered = applyFilters(
        issues,
        const FilterState(selectedPriorities: {'high'}),
      );
      expect(filtered.length, 1);
      expect(filtered[0].id, 'i1');
    });

    test('filters by assignee', () {
      final issues = [
        makeIssue(id: 'i1', assignees: ['u1']),
        makeIssue(id: 'i2', assignees: ['u2']),
      ];
      final filtered = applyFilters(
        issues,
        const FilterState(selectedAssignees: {'u1'}),
      );
      expect(filtered.length, 1);
      expect(filtered[0].id, 'i1');
    });

    test('filters by label', () {
      final issues = [
        makeIssue(id: 'i1', labels: ['l1']),
        makeIssue(id: 'i2', labels: ['l2']),
      ];
      final filtered = applyFilters(
        issues,
        const FilterState(selectedLabels: {'l1'}),
      );
      expect(filtered.length, 1);
      expect(filtered[0].id, 'i1');
    });

    test('returns all issues when no filters are active', () {
      final issues = [makeIssue(id: 'i1'), makeIssue(id: 'i2')];
      final filtered = applyFilters(issues, const FilterState());
      expect(filtered.length, 2);
    });

    test('combines multiple filters (AND logic)', () {
      final issues = [
        makeIssue(id: 'i1', priority: 'high', state: 's1'),
        makeIssue(id: 'i2', priority: 'high', state: 's2'),
        makeIssue(id: 'i3', priority: 'low', state: 's1'),
      ];
      final filtered = applyFilters(
        issues,
        const FilterState(
          selectedPriorities: {'high'},
          selectedStates: {'s1'},
        ),
      );
      expect(filtered.length, 1);
      expect(filtered[0].id, 'i1');
    });

    test('excludes issues with null state when state filter active', () {
      final issues = [makeIssue(id: 'i1', state: null)];
      final filtered = applyFilters(
        issues,
        const FilterState(selectedStates: {'s1'}),
      );
      expect(filtered, isEmpty);
    });
  });

  group('applySorting', () {
    test('sorts by createdAt ascending', () {
      final issues = [
        makeIssue(id: 'i2', createdAt: DateTime(2025, 3, 1)),
        makeIssue(id: 'i1', createdAt: DateTime(2025, 1, 1)),
      ];
      final sorted = applySorting(issues, SortField.createdAt, true);

      expect(sorted[0].id, 'i1');
      expect(sorted[1].id, 'i2');
    });

    test('sorts by createdAt descending', () {
      final issues = [
        makeIssue(id: 'i1', createdAt: DateTime(2025, 1, 1)),
        makeIssue(id: 'i2', createdAt: DateTime(2025, 3, 1)),
      ];
      final sorted = applySorting(issues, SortField.createdAt, false);

      expect(sorted[0].id, 'i2');
      expect(sorted[1].id, 'i1');
    });

    test('sorts by updatedAt ascending', () {
      final issues = [
        makeIssue(id: 'i2', updatedAt: DateTime(2025, 6, 1)),
        makeIssue(id: 'i1', updatedAt: DateTime(2025, 2, 1)),
      ];
      final sorted = applySorting(issues, SortField.updatedAt, true);

      expect(sorted[0].id, 'i1');
      expect(sorted[1].id, 'i2');
    });

    test('sorts by priority ascending (urgent first)', () {
      final issues = [
        makeIssue(id: 'i1', priority: 'low'),
        makeIssue(id: 'i2', priority: 'urgent'),
        makeIssue(id: 'i3', priority: 'medium'),
      ];
      final sorted = applySorting(issues, SortField.priority, true);

      expect(sorted[0].id, 'i2');
      expect(sorted[1].id, 'i3');
      expect(sorted[2].id, 'i1');
    });

    test('sorts by priority descending (none first)', () {
      final issues = [
        makeIssue(id: 'i1', priority: 'urgent'),
        makeIssue(id: 'i2', priority: 'none'),
      ];
      final sorted = applySorting(issues, SortField.priority, false);

      expect(sorted[0].id, 'i2');
      expect(sorted[1].id, 'i1');
    });

    test('does not mutate original list', () {
      final issues = [
        makeIssue(id: 'i2', createdAt: DateTime(2025, 3, 1)),
        makeIssue(id: 'i1', createdAt: DateTime(2025, 1, 1)),
      ];
      applySorting(issues, SortField.createdAt, true);

      expect(issues[0].id, 'i2'); // original unchanged
    });
  });

  group('groupLabel', () {
    test('maps started to In Progress', () {
      expect(groupLabel('started'), 'In Progress');
    });

    test('maps unstarted to Todo', () {
      expect(groupLabel('unstarted'), 'Todo');
    });

    test('maps backlog to Backlog', () {
      expect(groupLabel('backlog'), 'Backlog');
    });

    test('maps completed to Done', () {
      expect(groupLabel('completed'), 'Done');
    });

    test('maps cancelled to Cancelled', () {
      expect(groupLabel('cancelled'), 'Cancelled');
    });

    test('returns unknown group as-is', () {
      expect(groupLabel('custom'), 'custom');
    });
  });

  group('groupByLabel', () {
    test('uses groupLabel for state field', () {
      expect(groupByLabel(GroupByField.state, 'started'), 'In Progress');
    });

    test('capitalizes priority', () {
      expect(groupByLabel(GroupByField.priority, 'high'), 'High');
    });

    test('returns key as-is for assignee', () {
      expect(groupByLabel(GroupByField.assignee, 'Alice'), 'Alice');
    });

    test('returns key as-is for label', () {
      expect(groupByLabel(GroupByField.label, 'Bug'), 'Bug');
    });
  });
}
