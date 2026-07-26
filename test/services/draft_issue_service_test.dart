import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/draft_issue.dart';
import 'package:plane_mobile/services/draft_issue_service.dart';

void main() {
  group('DraftIssueService.parseDrafts', () {
    test('reads the paginated envelope', () {
      // `draft-issues/` runs through the same `self.paginate` as `issues/`, so
      // it answers with an envelope. A parser that assumed a list would report
      // an empty drafts listing, which is indistinguishable from having none —
      // and that is exactly the complaint this feature exists to fix.
      final parsed = DraftIssueService.parseDrafts({
        'results': [
          {'id': 'd1', 'name': 'Half a thought', 'project_id': 'p1'},
        ],
        'next_cursor': '100:1:0',
        'total_results': 1,
      });

      expect(parsed, hasLength(1));
      expect(parsed.single.id, 'd1');
      expect(parsed.single.issue.name, 'Half a thought');
    });

    test('accepts a bare list, which is what a non-paginated view would send',
        () {
      final parsed = DraftIssueService.parseDrafts([
        {'id': 'd1', 'name': 'Half a thought'},
      ]);
      expect(parsed, hasLength(1));
    });

    test('returns empty rather than throwing on an unexpected shape', () {
      expect(DraftIssueService.parseDrafts(null), isEmpty);
      expect(DraftIssueService.parseDrafts({'grouped_by': 'state'}), isEmpty);
      expect(DraftIssueService.parseDrafts('nope'), isEmpty);
    });

    test('survives a draft with no name', () {
      final parsed = DraftIssueService.parseDrafts({
        'results': [
          {'id': 'd1', 'name': null},
        ],
      });
      expect(parsed.single.hasName, isFalse);
    });
  });

  group('DraftIssueService.toWritePayload', () {
    test('renames the four relations the draft serialiser declares', () {
      // DraftIssueCreateSerializer declares state_id / parent_id / label_ids /
      // assignee_ids explicitly. The plain names are not rejected — they are
      // dropped as unknown keys, so the write looks like a success and changes
      // nothing.
      final out = DraftIssueService.toWritePayload({
        'state': 's1',
        'parent': 'i1',
        'labels': ['l1'],
        'assignees': ['u1'],
      });

      expect(out, {
        'state_id': 's1',
        'parent_id': 'i1',
        'label_ids': ['l1'],
        'assignee_ids': ['u1'],
      });
    });

    test('leaves everything else exactly as it was', () {
      final out = DraftIssueService.toWritePayload({
        'name': 'Draft',
        'description_html': '<p>x</p>',
        'priority': 'urgent',
        'start_date': '2025-01-01',
        // Read straight out of request.data by the view, past the serialiser.
        'cycle_id': 'c1',
        'module_ids': ['m1'],
        // The Issue model's own field name, not an id-suffixed one.
        'estimate_point': 'ep1',
      });

      expect(out['name'], 'Draft');
      expect(out['description_html'], '<p>x</p>');
      expect(out['priority'], 'urgent');
      expect(out['start_date'], '2025-01-01');
      expect(out['cycle_id'], 'c1');
      expect(out['module_ids'], ['m1']);
      expect(out['estimate_point'], 'ep1');
    });

    test('passes a null through rather than dropping the key', () {
      // Clearing a relation is a real edit. Dropping the key would make the
      // serialiser leave the old value standing.
      final out = DraftIssueService.toWritePayload({'state': null});
      expect(out.containsKey('state_id'), isTrue);
      expect(out['state_id'], isNull);
    });
  });

  group('the promotion payload as it goes on the wire', () {
    test('an override wins over what the draft holds', () {
      // The editor promotes with the form's contents rather than saving first:
      // promotion deletes the draft, so a prior PATCH writes to a row that is
      // about to stop existing.
      final draft = DraftIssue.fromJson({
        'id': 'd1',
        'name': 'Old title',
        'project_id': 'p1',
        'priority': 'low',
        'label_ids': ['l1'],
      });

      final body = DraftIssueService.toWritePayload({
        ...draft.toPromoteJson(),
        'name': 'New title',
        'priority': 'urgent',
      });

      expect(body['name'], 'New title');
      expect(body['priority'], 'urgent');
      // Untouched by the form, so it has to come from the draft or be lost.
      expect(body['label_ids'], ['l1']);
    });
  });
}
