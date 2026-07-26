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

    // The internal API nests the work item under `issue` rather than sending
    // its id there — both IntakeIssueSerializer and IntakeIssueDetailSerializer
    // declare `issue` as a nested serializer, so the flat spelling the v1
    // surface uses never arrives.
    test('reads the internal shape, where `issue` is the object itself', () {
      final intakeIssue = IntakeIssue.fromJson({
        'id': 'row-1',
        'status': -2,
        'created_by': 'user-7',
        'issue': {
          'id': 'work-item-1',
          'name': 'Broken export',
          'sequence_id': 42,
          'label_ids': ['label-1'],
        },
      });

      expect(intakeIssue.issueId, 'work-item-1');
      expect(intakeIssue.issue.name, 'Broken export');
      expect(intakeIssue.issue.labels, ['label-1']);
      expect(intakeIssue.createdBy, 'user-7');
    });

    test('reads the duplicate target and the name the server expanded', () {
      final intakeIssue = IntakeIssue.fromJson({
        'id': 'row-1',
        'status': 2,
        'duplicate_to': 'work-item-9',
        'duplicate_issue_detail': {
          'id': 'work-item-9',
          'name': 'The original report',
        },
        'issue': {'id': 'work-item-1', 'name': 'Same thing again'},
      });

      expect(intakeIssue.duplicateTo, 'work-item-9');
      expect(intakeIssue.duplicateName, 'The original report');
    });

    // The list serializer sends the bare id with no expansion, so a row can
    // know it is a duplicate without being able to name what of.
    test('a duplicate id with no expansion leaves the name unknown', () {
      final intakeIssue = IntakeIssue.fromJson({
        'status': 2,
        'duplicate_to': 'work-item-9',
      });

      expect(intakeIssue.duplicateTo, 'work-item-9');
      expect(intakeIssue.duplicateName, isNull);
    });

    // Neither intake serializer lists created_at or updated_at among its
    // fields, so these are null on every response this app receives. Null
    // rather than now(): a fabricated "submitted just now" on every row is
    // worse than no timestamp, and the one a user wants is the work item's.
    test('leaves the row timestamps null when the server omits them', () {
      final intakeIssue = IntakeIssue.fromJson({
        'id': 'row-1',
        'status': -2,
        'issue': {
          'id': 'work-item-1',
          'name': 'Broken export',
          'created_at': '2025-01-01T00:00:00Z',
        },
      });

      expect(intakeIssue.createdAt, isNull);
      expect(intakeIssue.updatedAt, isNull);
      expect(intakeIssue.issue.createdAt, DateTime.utc(2025, 1, 1));
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

  group('IntakeStatus', () {
    test('the constants are the column\'s own IntegerChoices', () {
      expect(IntakeStatus.pending, -2);
      expect(IntakeStatus.declined, -1);
      expect(IntakeStatus.snoozed, 0);
      expect(IntakeStatus.accepted, 1);
      expect(IntakeStatus.duplicate, 2);
    });

    // Which statuses each tab asks for. Getting these wrong does not fail —
    // it quietly shows the wrong half of the queue.
    test('open is pending plus snoozed, closed is the three terminal ones', () {
      expect(IntakeStatus.open, [-2, 0]);
      expect(IntakeStatus.closed, [1, -1, 2]);
      // Between them they cover all five, with no overlap.
      expect({...IntakeStatus.open, ...IntakeStatus.closed}, hasLength(5));
    });

    test('only pending and snoozed entries are still actionable', () {
      expect(IntakeStatus.isOpen(IntakeStatus.pending), isTrue);
      expect(IntakeStatus.isOpen(IntakeStatus.snoozed), isTrue);
      expect(IntakeStatus.isOpen(IntakeStatus.accepted), isFalse);
      expect(IntakeStatus.isOpen(IntakeStatus.declined), isFalse);
      expect(IntakeStatus.isOpen(IntakeStatus.duplicate), isFalse);
    });
  });

  // The server never sweeps an expired snooze back to pending — the row keeps
  // status 0 forever — so anything treating "snoozed" as "hidden" loses the
  // entry on the very day it was meant to resurface.
  group('IntakeIssue.snoozeExpired', () {
    IntakeIssue snoozedUntil(DateTime till) => IntakeIssue.fromJson({
          'status': 0,
          'snoozed_till': till.toUtc().toIso8601String(),
        });

    test('a past wake date has expired', () {
      expect(
        snoozedUntil(DateTime.now().subtract(const Duration(days: 1)))
            .snoozeExpired,
        isTrue,
      );
    });

    test('a future wake date has not', () {
      expect(
        snoozedUntil(DateTime.now().add(const Duration(days: 1))).snoozeExpired,
        isFalse,
      );
    });

    test('a non-snoozed entry never counts as expired', () {
      // duplicate_to and snoozed_till can both be set on the same row if an
      // entry was snoozed and then marked duplicate; only the status decides.
      final entry = IntakeIssue.fromJson({
        'status': 2,
        'snoozed_till': '2020-01-01T00:00:00Z',
      });
      expect(entry.snoozeExpired, isFalse);
      expect(entry.isOpen, isFalse);
    });

    test('a snooze with no date is not expired', () {
      expect(IntakeIssue.fromJson({'status': 0}).snoozeExpired, isFalse);
    });
  });
}
