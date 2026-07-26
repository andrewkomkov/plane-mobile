import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/archived_issue_service.dart';

void main() {
  // `archived-issues/` runs through the same `self.paginate` as `issues/`, so
  // it answers with an envelope rather than a bare list. A parser that assumed
  // a list would find nothing and report an empty archive, which is
  // indistinguishable from a project that has none.
  group('ArchivedIssueService.parseArchivedIssues', () {
    test('reads the paginated envelope', () {
      final parsed = ArchivedIssueService.parseArchivedIssues({
        'results': [
          {
            'id': 'i1',
            'name': 'Old bug',
            'sequence_id': 12,
            'archived_at': '2025-03-04T10:00:00Z',
          },
        ],
        'next_cursor': '50:1:0',
        'total_results': 1,
      });

      expect(parsed, hasLength(1));
      expect(parsed.single.issue.name, 'Old bug');
      expect(parsed.single.issue.sequenceId, 12);
      expect(parsed.single.archivedAt, DateTime.utc(2025, 3, 4, 10));
    });

    test('reads the internal API id spellings on the way through', () {
      // `issue_on_results` emits state_id / assignee_ids / label_ids, not the
      // external API's state / assignees / labels.
      final parsed = ArchivedIssueService.parseArchivedIssues({
        'results': [
          {
            'id': 'i1',
            'name': 'Old bug',
            'state_id': 'state-9',
            'assignee_ids': ['u1', 'u2'],
            'label_ids': ['l1'],
            'archived_at': '2025-03-04T10:00:00Z',
          },
        ],
      });

      final issue = parsed.single.issue;
      expect(issue.state, 'state-9');
      expect(issue.assignees, ['u1', 'u2']);
      expect(issue.labels, ['l1']);
    });

    test('accepts a bare list, which is what a non-paginated view would send',
        () {
      final parsed = ArchivedIssueService.parseArchivedIssues([
        {'id': 'i1', 'name': 'Old bug', 'archived_at': '2025-03-04T10:00:00Z'},
      ]);
      expect(parsed, hasLength(1));
    });

    test('returns empty rather than throwing on an unexpected shape', () {
      expect(ArchivedIssueService.parseArchivedIssues(null), isEmpty);
      expect(ArchivedIssueService.parseArchivedIssues({'grouped_by': 'state'}),
          isEmpty);
      expect(ArchivedIssueService.parseArchivedIssues('nope'), isEmpty);
    });

    test('an unparseable archived_at leaves the row, not the timestamp', () {
      final parsed = ArchivedIssueService.parseArchivedIssues({
        'results': [
          {'id': 'i1', 'name': 'Old bug', 'archived_at': 'not a date'},
        ],
      });
      expect(parsed.single.issue.id, 'i1');
      expect(parsed.single.archivedAt, isNull);
    });
  });
}
