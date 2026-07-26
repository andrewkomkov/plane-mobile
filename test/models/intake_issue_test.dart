import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/intake_issue.dart';

void main() {
  group('IntakeIssue.fromJson', () {
    // Shaped after IntakeIssueSerializer in plane/api/serializers/intake.py:
    // `fields = "__all__"` plus the declared `issue_detail` and the `inbox`
    // alias for the intake id.
    Map<String, dynamic> serverJson() => {
          'id': 'intake-row-1',
          'status': -2,
          'snoozed_till': null,
          'source': 'IN-APP',
          'created_at': '2025-01-01T00:00:00Z',
          'updated_at': '2025-02-01T00:00:00Z',
          'intake': 'intake-1',
          'inbox': 'intake-1',
          'issue': 'work-item-1',
          'issue_detail': {
            'id': 'work-item-1',
            'name': 'Broken export',
            'priority': 'high',
            'sequence_id': 42,
            'state': {
              'id': 'state-triage',
              'name': 'Triage',
              'group': 'triage',
              'color': '#4E5355',
            },
            'assignees': [],
            'labels': [],
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
        };

    test('keeps the row id and the work item id apart', () {
      final intakeIssue = IntakeIssue.fromJson(serverJson());

      expect(intakeIssue.id, 'intake-row-1');
      // The detail routes key on the work item, so this is the one that goes
      // into a URL. Getting these two the wrong way round 404s.
      expect(intakeIssue.issueId, 'work-item-1');
    });

    test('parses the expanded work item', () {
      final intakeIssue = IntakeIssue.fromJson(serverJson());

      expect(intakeIssue.issue.id, 'work-item-1');
      expect(intakeIssue.issue.name, 'Broken export');
      expect(intakeIssue.issue.priority, 'high');
      expect(intakeIssue.issue.sequenceId, 42);
      expect(intakeIssue.status, -2);
      expect(intakeIssue.source, 'IN-APP');
      expect(intakeIssue.createdAt, DateTime.utc(2025, 1, 1));
      expect(intakeIssue.updatedAt, DateTime.utc(2025, 2, 1));
    });

    test('collapses the nested state object to its id', () {
      // IssueExpandSerializer renders state through StateLiteSerializer, but
      // Issue.state is a String — an unflattened object throws on parse.
      final intakeIssue = IntakeIssue.fromJson(serverJson());

      expect(intakeIssue.issue.state, 'state-triage');
      expect(intakeIssue.issue.stateDetail, 'Triage');
    });

    test('falls back to the expanded id when only the object is present', () {
      final json = serverJson()..remove('issue');
      expect(IntakeIssue.fromJson(json).issueId, 'work-item-1');
    });

    test('survives a response narrowed by ?fields=', () {
      final intakeIssue = IntakeIssue.fromJson({
        'id': 'intake-row-1',
        'issue': 'work-item-1',
        'status': 1,
      });

      expect(intakeIssue.issueId, 'work-item-1');
      expect(intakeIssue.issue.name, '');
      expect(intakeIssue.status, 1);
    });

    test('defaults to pending on an empty payload', () {
      final intakeIssue = IntakeIssue.fromJson(<String, dynamic>{});

      expect(intakeIssue.id, '');
      expect(intakeIssue.issueId, '');
      expect(intakeIssue.status, -2);
      expect(intakeIssue.snoozedTill, isNull);
    });

    test('parses a snooze timestamp', () {
      final intakeIssue = IntakeIssue.fromJson({
        'status': 0,
        'snoozed_till': '2025-03-01T12:00:00Z',
      });

      expect(intakeIssue.snoozedTill, DateTime.utc(2025, 3, 1, 12));
    });
  });

  group('IntakeIssue.statusLabel', () {
    test('names every triage status', () {
      String labelFor(int status) =>
          IntakeIssue.fromJson({'status': status}).statusLabel;

      expect(labelFor(-2), 'Pending');
      expect(labelFor(-1), 'Declined');
      expect(labelFor(0), 'Snoozed');
      expect(labelFor(1), 'Accepted');
      expect(labelFor(2), 'Duplicate');
      expect(labelFor(99), 'Unknown');
    });
  });
}
