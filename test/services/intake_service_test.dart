import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/intake_issue.dart';
import 'package:plane_mobile/services/intake_service.dart';

void main() {
  // `IntakeIssueViewSet.list` runs through `self.paginate`, so the queue comes
  // back inside an envelope. A parser that only understood a bare list would
  // report every project's intake as empty, which looks exactly like a project
  // nobody has submitted to.
  group('IntakeService.parseIntakeIssues', () {
    test('reads the paginated envelope', () {
      final parsed = IntakeService.parseIntakeIssues({
        'total_count': 2,
        'results': [
          {
            'id': 'row-1',
            'status': -2,
            'issue': {
              'id': 'wi-1',
              'name': 'Login is broken',
              'sequence_id': 7
            },
          },
          {
            'id': 'row-2',
            'status': 0,
            'snoozed_till': '2030-01-01T00:00:00Z',
            'issue': {'id': 'wi-2', 'name': 'Add dark mode', 'sequence_id': 8},
          },
        ],
      });

      expect(parsed, hasLength(2));
      expect(parsed.first.issue.name, 'Login is broken');
      expect(parsed.first.issueId, 'wi-1');
      expect(parsed.last.status, IntakeStatus.snoozed);
    });

    test('reads a bare list, which the v1 surface answers with', () {
      final parsed = IntakeService.parseIntakeIssues([
        {
          'id': 'row-1',
          'status': 1,
          'issue': 'wi-1',
          'issue_detail': {'id': 'wi-1', 'name': 'Accepted thing'},
        },
      ]);

      expect(parsed.single.issue.name, 'Accepted thing');
      expect(parsed.single.status, IntakeStatus.accepted);
    });

    test('answers empty for the 404 error body rather than throwing', () {
      // A project with no Intake row answers {"error": "Intake not found"}.
      // Dio raises on the status code, but the same body reaches this parser
      // whenever an interceptor swallows the error.
      expect(
        IntakeService.parseIntakeIssues({'error': 'Intake not found'}),
        isEmpty,
      );
      expect(IntakeService.parseIntakeIssues(null), isEmpty);
    });
  });

  // The serializer ignores keys it does not know, so a wrong key here returns
  // 200 and does nothing. These pin the exact bodies Plane's own client sends
  // in web/core/store/inbox/inbox-issue.store.ts.
  group('IntakeService.triagePayload', () {
    test('accept is a bare status', () {
      expect(
        IntakeService.triagePayload(status: IntakeStatus.accepted),
        {'status': 1},
      );
    });

    test('decline is a bare status, with no reason field', () {
      // intake_issues has no column for one and the serializer has no field
      // for one. Anything sent under that name would be dropped in silence.
      final payload =
          IntakeService.triagePayload(status: IntakeStatus.declined);
      expect(payload, {'status': -1});
      expect(payload.containsKey('reason'), isFalse);
    });

    test('snooze carries the wake date as UTC', () {
      final payload = IntakeService.triagePayload(
        status: IntakeStatus.snoozed,
        // A time with an offset, so a local-time serialisation would show.
        snoozedTill: DateTime.utc(2030, 3, 1, 9, 30),
      );

      expect(payload['status'], 0);
      expect(payload['snoozed_till'], '2030-03-01T09:30:00.000Z');
    });

    test('a local wake date is converted, not relabelled', () {
      final local = DateTime(2030, 3, 1, 9, 30);
      final payload = IntakeService.triagePayload(
        status: IntakeStatus.snoozed,
        snoozedTill: local,
      );

      expect(
        payload['snoozed_till'],
        local.toUtc().toIso8601String(),
      );
      expect(payload['snoozed_till'].toString().endsWith('Z'), isTrue);
    });

    test('un-snooze names snoozed_till explicitly so the old date is cleared',
        () {
      final payload = IntakeService.triagePayload(
        status: IntakeStatus.pending,
        clearSnooze: true,
      );

      // A PATCH only clears what it names. Omitting the key would leave a
      // stale wake date on an entry that is back in the pending queue.
      expect(payload.containsKey('snoozed_till'), isTrue);
      expect(payload['snoozed_till'], isNull);
      expect(payload['status'], -2);
    });

    test('duplicate carries the target work item', () {
      expect(
        IntakeService.triagePayload(
          status: IntakeStatus.duplicate,
          duplicateTo: 'wi-original',
        ),
        {'status': 2, 'duplicate_to': 'wi-original'},
      );
    });

    test('nothing extra is sent when nothing extra was asked for', () {
      final payload =
          IntakeService.triagePayload(status: IntakeStatus.accepted);
      expect(payload.keys, ['status']);
    });
  });

  // search-issues/ answers with a flat .values() projection, so the keys are
  // the ORM's join spellings rather than anything a serializer produced.
  group('IntakeDuplicateCandidate.fromJson', () {
    test('reads the double-underscore join keys', () {
      final candidate = IntakeDuplicateCandidate.fromJson({
        'id': 'wi-9',
        'name': 'Login is broken',
        'sequence_id': 42,
        'project__identifier': 'PLM',
        'project__name': 'Plane Mobile',
        'state__name': 'In Progress',
        'state__group': 'started',
      });

      expect(candidate.id, 'wi-9');
      expect(candidate.label, 'PLM-42');
      expect(candidate.stateName, 'In Progress');
    });

    test('survives a row with nothing but an id', () {
      final candidate = IntakeDuplicateCandidate.fromJson({'id': 'wi-9'});

      expect(candidate.name, '');
      expect(candidate.label, '-0');
      expect(candidate.stateName, isNull);
    });
  });
}
