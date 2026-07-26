import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/draft_issue.dart';

void main() {
  DraftIssue draft(Map<String, dynamic> overrides) => DraftIssue.fromJson({
        'id': 'draft-1',
        'name': 'Half a thought',
        'project_id': 'proj-1',
        'priority': 'high',
        ...overrides,
      });

  group('DraftIssue.fromJson', () {
    test('reads the internal API id spellings, as a work item does', () {
      // DraftIssueSerializer emits the same id-suffixed names as the work-item
      // serialisers, which is the whole reason the contents are parsed as an
      // Issue rather than getting a second parser to keep in step.
      final d = draft({
        'state_id': 'state-9',
        'assignee_ids': ['u1', 'u2'],
        'label_ids': ['l1'],
        'parent_id': 'issue-7',
        'cycle_id': 'cycle-3',
        'module_ids': ['m1', 'm2'],
        'estimate_point': 'ep-1',
      });

      expect(d.issue.state, 'state-9');
      expect(d.issue.assignees, ['u1', 'u2']);
      expect(d.issue.labels, ['l1']);
      expect(d.issue.parent, 'issue-7');
      expect(d.issue.cycleId, 'cycle-3');
      expect(d.issue.moduleIds, ['m1', 'm2']);
      expect(d.issue.estimatePoint, 'ep-1');
      expect(d.issue.project, 'proj-1');
    });

    test('a draft id is its own, not a work item id', () {
      expect(draft({}).id, 'draft-1');
    });

    test('has no sequence id, because the serialiser does not send one', () {
      // Left at the parser's zero. The list must not render it, or every draft
      // in the project reads "PLM-0".
      expect(draft({}).issue.sequenceId, 0);
    });
  });

  group('DraftIssue.rowIssue', () {
    test('leaves a named draft alone', () {
      final d = draft({});
      expect(identical(d.rowIssue, d.issue), isTrue);
    });

    test('gives an unnamed draft something to be called', () {
      // DraftIssue.name is nullable server-side and Plane's own draft modal
      // saves without one, so a row with no title is a shape that arrives.
      final d = draft({'name': null});
      expect(d.hasName, isFalse);
      expect(d.rowIssue.name, DraftIssue.untitled);
    });

    test('a whitespace-only name counts as no name', () {
      expect(draft({'name': '   '}).rowIssue.name, DraftIssue.untitled);
    });

    test('the stand-in does not leak back into the draft itself', () {
      // The editor prefills from `issue`, and opening a nameless draft with
      // "Untitled draft" already typed in would save that as its real name.
      final d = draft({'name': ''});
      expect(d.issue.name, '');
    });

    test('carries the properties the row draws', () {
      final d = draft({
        'name': '',
        'state_id': 'state-9',
        'assignee_ids': ['u1'],
        'label_ids': ['l1'],
        'target_date': '2025-01-01',
      });
      expect(d.rowIssue.state, 'state-9');
      expect(d.rowIssue.assignees, ['u1']);
      expect(d.rowIssue.labels, ['l1']);
      expect(d.rowIssue.targetDate, '2025-01-01');
    });
  });

  group('DraftIssue.canPromote', () {
    test('needs a project, because the server refuses without one', () {
      expect(draft({'project_id': null}).canPromote, isFalse);
    });

    test('needs a name, because IssueCreateSerializer requires one', () {
      expect(draft({'name': ''}).canPromote, isFalse);
    });

    test('is true once it has both', () {
      expect(draft({}).canPromote, isTrue);
    });
  });

  group('DraftIssue.toPromoteJson', () {
    test('re-sends the whole draft, because the endpoint copies nothing', () {
      // `create_draft_to_issue` builds the work item out of request.data and
      // takes only the project from the draft row, then deletes the row. A
      // short payload silently loses whatever it left out.
      final json = draft({
        'description_html': '<p>notes</p>',
        'state_id': 'state-9',
        'assignee_ids': ['u1'],
        'label_ids': ['l1'],
        'start_date': '2025-01-01',
        'target_date': '2025-02-01',
        'parent_id': 'issue-7',
        'estimate_point': 'ep-1',
      }).toPromoteJson();

      expect(json['name'], 'Half a thought');
      expect(json['description_html'], '<p>notes</p>');
      expect(json['state'], 'state-9');
      expect(json['priority'], 'high');
      expect(json['assignees'], ['u1']);
      expect(json['labels'], ['l1']);
      expect(json['start_date'], '2025-01-01');
      expect(json['target_date'], '2025-02-01');
      expect(json['parent'], 'issue-7');
      expect(json['estimate_point'], 'ep-1');
    });

    test('spells cycle and module the way the view reads them', () {
      // Those two are pulled straight out of request.data by the view, not by
      // the serialiser, so they must already carry the server's names and must
      // survive the rename pass untouched.
      final json = draft({
        'cycle_id': 'cycle-3',
        'module_ids': ['m1'],
      }).toPromoteJson();

      expect(json['cycle_id'], 'cycle-3');
      expect(json['module_ids'], ['m1']);
    });

    test('omits what the draft does not hold', () {
      final json = draft({}).toPromoteJson();
      expect(json.containsKey('description_html'), isFalse);
      expect(json.containsKey('assignees'), isFalse);
      expect(json.containsKey('cycle_id'), isFalse);
    });
  });
}
