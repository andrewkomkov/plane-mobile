import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/issue.dart';
import '../test_helpers.dart';

void main() {
  group('Issue.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'abc-123',
        'name': 'Fix login bug',
        'description_html': '<p>Details</p>',
        'state': 'state-1',
        'state_detail': {'name': 'In Progress'},
        'priority': 'high',
        'sequence_id': 42,
        'project_detail': {'name': 'MyProject'},
        'assignees': ['user-1', 'user-2'],
        'labels': ['label-1'],
        'created_at': '2025-03-01T10:00:00Z',
        'updated_at': '2025-03-02T12:00:00Z',
        'created_by': 'user-1',
        'project': 'proj-1',
        'start_date': '2025-03-01',
        'target_date': '2025-03-15',
        'parent': 'parent-1',
        'sub_issues_count': 3,
      };

      final issue = Issue.fromJson(json);

      expect(issue.id, 'abc-123');
      expect(issue.name, 'Fix login bug');
      expect(issue.descriptionHtml, '<p>Details</p>');
      expect(issue.state, 'state-1');
      expect(issue.priority, 'high');
      expect(issue.sequenceId, 42);
      expect(issue.assignees, ['user-1', 'user-2']);
      expect(issue.labels, ['label-1']);
      expect(issue.createdAt, DateTime.utc(2025, 3, 1, 10));
      expect(issue.updatedAt, DateTime.utc(2025, 3, 2, 12));
      expect(issue.createdBy, 'user-1');
      expect(issue.project, 'proj-1');
      expect(issue.startDate, '2025-03-01');
      expect(issue.targetDate, '2025-03-15');
      expect(issue.parent, 'parent-1');
      expect(issue.subIssuesCount, 3);
    });

    test('handles missing optional fields with defaults', () {
      final json = <String, dynamic>{};
      final issue = Issue.fromJson(json);

      expect(issue.id, '');
      expect(issue.name, '');
      expect(issue.descriptionHtml, isNull);
      expect(issue.state, isNull);
      expect(issue.priority, 'none');
      expect(issue.sequenceId, 0);
      expect(issue.assignees, isEmpty);
      expect(issue.labels, isEmpty);
      expect(issue.createdBy, isNull);
      expect(issue.project, isNull);
      expect(issue.startDate, isNull);
      expect(issue.targetDate, isNull);
      expect(issue.parent, isNull);
      expect(issue.subIssuesCount, 0);
    });

    test('handles null assignees and labels', () {
      final json = {
        'assignees': null,
        'labels': null,
      };
      final issue = Issue.fromJson(json);
      expect(issue.assignees, isEmpty);
      expect(issue.labels, isEmpty);
    });

    test('handles invalid date strings gracefully', () {
      final json = {
        'created_at': 'not-a-date',
        'updated_at': 'also-not-a-date',
      };
      final issue = Issue.fromJson(json);
      // Falls back to DateTime.now(), so just check it parsed without throwing
      expect(issue.createdAt, isA<DateTime>());
      expect(issue.updatedAt, isA<DateTime>());
    });
  });

  group('Issue.toCreateJson', () {
    test('includes required fields', () {
      final issue = makeIssue(name: 'My task', priority: 'high');
      final json = issue.toCreateJson();

      expect(json['name'], 'My task');
      expect(json['priority'], 'high');
    });

    test('includes optional fields when present', () {
      final issue = makeIssue(
        descriptionHtml: '<p>Desc</p>',
        state: 'state-1',
        assignees: ['u1'],
        labels: ['l1'],
        startDate: '2025-01-01',
        targetDate: '2025-02-01',
        parent: 'p1',
      );
      final json = issue.toCreateJson();

      expect(json['description_html'], '<p>Desc</p>');
      expect(json['state'], 'state-1');
      expect(json['assignees'], ['u1']);
      expect(json['labels'], ['l1']);
      expect(json['start_date'], '2025-01-01');
      expect(json['target_date'], '2025-02-01');
      expect(json['parent'], 'p1');
    });

    test('excludes empty assignees and labels', () {
      final issue = makeIssue(assignees: [], labels: []);
      final json = issue.toCreateJson();

      expect(json.containsKey('assignees'), isFalse);
      expect(json.containsKey('labels'), isFalse);
    });

    test('excludes null optional fields', () {
      final issue = makeIssue(
        descriptionHtml: null,
        state: null,
        startDate: null,
        targetDate: null,
        parent: null,
      );
      final json = issue.toCreateJson();

      expect(json.containsKey('description_html'), isFalse);
      expect(json.containsKey('state'), isFalse);
      expect(json.containsKey('start_date'), isFalse);
      expect(json.containsKey('target_date'), isFalse);
      expect(json.containsKey('parent'), isFalse);
    });
  });

  group('Issue.isOverdue', () {
    test('returns false when targetDate is null', () {
      final issue = makeIssue(targetDate: null);
      expect(issue.isOverdue, isFalse);
    });

    test('returns false when targetDate is invalid', () {
      final issue = makeIssue(targetDate: 'invalid');
      expect(issue.isOverdue, isFalse);
    });

    test('returns true when targetDate is in the past', () {
      final issue = makeIssue(targetDate: '2020-01-01');
      expect(issue.isOverdue, isTrue);
    });

    test('returns false when targetDate is far in the future', () {
      final issue = makeIssue(targetDate: '2099-12-31');
      expect(issue.isOverdue, isFalse);
    });
  });
}
