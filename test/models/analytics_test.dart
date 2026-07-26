import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/analytics.dart';

ScannedWorkItem item({
  String stateGroup = 'started',
  String priority = 'medium',
  DateTime? targetDate,
}) =>
    ScannedWorkItem(
      stateGroup: stateGroup,
      priority: priority,
      targetDate: targetDate,
    );

ProjectScan scan({
  String id = 'proj-1',
  String name = 'Project One',
  int? serverTotal,
  List<ScannedWorkItem> items = const [],
  bool failed = false,
}) =>
    ProjectScan(
      projectId: id,
      projectName: name,
      serverTotal: serverTotal ?? items.length,
      items: items,
      failed: failed,
    );

void main() {
  group('ScannedWorkItem.fromJson', () {
    final states = {'s-1': 'started', 's-2': 'completed'};

    test('resolves the state id to its group', () {
      final parsed = ScannedWorkItem.fromJson(
        {'id': 'i-1', 'state': 's-2', 'priority': 'high'},
        states,
      );

      expect(parsed.stateGroup, 'completed');
      expect(parsed.priority, 'high');
      expect(parsed.targetDate, isNull);
    });

    test('falls back to backlog for an unknown or missing state', () {
      expect(
        ScannedWorkItem.fromJson({'state': 'nope'}, states).stateGroup,
        'backlog',
      );
      expect(
        ScannedWorkItem.fromJson(<String, dynamic>{}, states).stateGroup,
        'backlog',
      );
    });

    test('defaults a missing priority to none', () {
      expect(
          ScannedWorkItem.fromJson({'state': 's-1'}, states).priority, 'none');
    });

    test('parses a date-only target date', () {
      final parsed = ScannedWorkItem.fromJson(
        {'state': 's-1', 'target_date': '2025-06-01'},
        states,
      );
      expect(parsed.targetDate, DateTime(2025, 6, 1));
    });

    test('treats an empty target date as none set', () {
      final parsed =
          ScannedWorkItem.fromJson({'state': 's-1', 'target_date': ''}, states);
      expect(parsed.targetDate, isNull);
    });
  });

  group('ScannedWorkItem.isOverdueAt', () {
    final now = DateTime(2025, 6, 10, 12);

    test('open work past its target date is overdue', () {
      expect(item(targetDate: DateTime(2025, 6, 1)).isOverdueAt(now), isTrue);
    });

    test('open work with a target date still ahead is not', () {
      expect(item(targetDate: DateTime(2025, 6, 20)).isOverdueAt(now), isFalse);
    });

    test('a target date of today counts as passed, as elsewhere in the app',
        () {
      expect(item(targetDate: DateTime(2025, 6, 10)).isOverdueAt(now), isTrue);
    });

    test('finished and cancelled work is never overdue', () {
      final late = DateTime(2025, 1, 1);
      expect(
        item(stateGroup: 'completed', targetDate: late).isOverdueAt(now),
        isFalse,
      );
      expect(
        item(stateGroup: 'cancelled', targetDate: late).isOverdueAt(now),
        isFalse,
      );
    });

    test('no target date means never overdue', () {
      expect(item().isOverdueAt(now), isFalse);
    });
  });

  group('ProjectScan', () {
    test('is complete when it read everything the server counted', () {
      expect(scan(serverTotal: 2, items: [item(), item()]).isComplete, isTrue);
    });

    test('is incomplete when the sweep fell short', () {
      expect(scan(serverTotal: 9, items: [item()]).isComplete, isFalse);
    });

    test('a project that could not be read is never complete, empty or not',
        () {
      // The trap: an unread project has no items and no server total, so it is
      // indistinguishable from an empty one by counting alone.
      expect(scan(serverTotal: 0, items: const [], failed: true).isComplete,
          isFalse);
    });

    test('counts by state group', () {
      final s = scan(items: [
        item(stateGroup: 'started'),
        item(stateGroup: 'started'),
        item(stateGroup: 'completed'),
      ]);

      expect(s.byStateGroup, {'started': 2, 'completed': 1});
    });
  });

  group('WorkspaceAnalytics.aggregate', () {
    final now = DateTime(2025, 6, 10, 12);

    test('folds projects into workspace totals', () {
      final data = WorkspaceAnalytics.aggregate(
        [
          scan(items: [
            item(stateGroup: 'backlog', priority: 'urgent'),
            item(stateGroup: 'completed', priority: 'low'),
          ]),
          scan(id: 'proj-2', name: 'Project Two', items: [
            item(stateGroup: 'started', priority: 'urgent'),
            item(stateGroup: 'cancelled', priority: 'none'),
          ]),
        ],
        now: now,
      );

      expect(data.total, 4);
      expect(data.scanned, 4);
      expect(data.byStateGroup,
          {'backlog': 1, 'completed': 1, 'started': 1, 'cancelled': 1});
      expect(data.byPriority, {'urgent': 2, 'low': 1, 'none': 1});
      expect(data.completed, 1);
      // Pending drops both the completed and the cancelled item.
      expect(data.pending, 2);
      expect(data.isComplete, isTrue);
    });

    test('overdue counts only open work with a passed target date', () {
      final data = WorkspaceAnalytics.aggregate(
        [
          scan(items: [
            item(stateGroup: 'started', targetDate: DateTime(2025, 5, 1)),
            item(stateGroup: 'backlog', targetDate: DateTime(2025, 12, 1)),
            item(stateGroup: 'completed', targetDate: DateTime(2025, 1, 1)),
            item(stateGroup: 'started'),
          ]),
        ],
        now: now,
      );

      expect(data.overdue, 1);
    });

    test('keeps the server total when the sweep did not reach it', () {
      final data = WorkspaceAnalytics.aggregate(
        [
          scan(serverTotal: 500, items: [item(), item()])
        ],
        now: now,
      );

      expect(data.total, 500);
      expect(data.scanned, 2);
      expect(data.isComplete, isFalse);
    });

    test('one unread project makes the whole sweep incomplete', () {
      final data = WorkspaceAnalytics.aggregate(
        [
          scan(items: [item(), item()]),
          scan(id: 'proj-2', name: 'Unreadable', failed: true),
        ],
        now: now,
      );

      // Counting alone would call this complete: 2 scanned, 2 in the total.
      expect(data.total, 2);
      expect(data.scanned, 2);
      expect(data.incompleteProjects, 1);
      expect(data.isComplete, isFalse);
    });

    test('no projects aggregates to an empty, complete result', () {
      final data = WorkspaceAnalytics.aggregate(const [], now: now);

      expect(data.isEmpty, isTrue);
      expect(data.isComplete, isTrue);
      expect(data.overdue, 0);
    });
  });
}
