import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/issue_service.dart';

void main() {
  // The relations endpoint does not return a list. It returns an object keyed
  // by relation kind, with each related work item's own fields flat inside.
  // The previous parser tested `response.data is List`, which could never be
  // true, so relations always came back empty even when the request succeeded.
  group('IssueService.parseIssueRelations', () {
    test('flattens the kind-keyed object and tags each entry', () {
      final parsed = IssueService.parseIssueRelations({
        'blocking': [
          {'id': 'i1', 'name': 'Ship the API', 'sequence_id': 4},
        ],
        'blocked_by': [
          {'id': 'i2', 'name': 'Design review', 'sequence_id': 5},
        ],
        'duplicate': [],
        'relates_to': [
          {'id': 'i3', 'name': 'Docs', 'sequence_id': 6},
        ],
      });

      expect(parsed.length, 3);
      expect(
        parsed.map((e) => e['relation_type']),
        containsAll(['blocking', 'blocked_by', 'relates_to']),
      );
      final blocking =
          parsed.firstWhere((e) => e['relation_type'] == 'blocking');
      expect(blocking['name'], 'Ship the API');
      expect(blocking['id'], 'i1');
    });

    test('drops empty kinds', () {
      final parsed = IssueService.parseIssueRelations({
        'blocking': [],
        'relates_to': [],
      });
      expect(parsed, isEmpty);
    });

    // The key is authoritative: the server files an item under the kind as seen
    // from *this* work item, while the row's own relation_type is as stored.
    test('the kind key wins over a relation_type on the row', () {
      final parsed = IssueService.parseIssueRelations({
        'blocking': [
          {'id': 'i1', 'name': 'X', 'relation_type': 'blocked_by'},
        ],
      });
      expect(parsed.single['relation_type'], 'blocking');
    });

    test('returns empty for a list, which is not the shape this sends', () {
      expect(IssueService.parseIssueRelations([]), isEmpty);
      expect(
        IssueService.parseIssueRelations([
          {'id': 'i1'},
        ]),
        isEmpty,
      );
    });

    test('returns empty for null and skips non-map entries', () {
      expect(IssueService.parseIssueRelations(null), isEmpty);
      expect(
        IssueService.parseIssueRelations({
          'blocking': ['not-a-map'],
        }),
        isEmpty,
      );
    });

    test('carries the extra kinds the server also files', () {
      // start_before / finish_before exist server-side; they must not vanish
      // silently just because the UI does not offer them for creation.
      final parsed = IssueService.parseIssueRelations({
        'start_before': [
          {'id': 'i9', 'name': 'Groundwork'},
        ],
      });
      expect(parsed.single['relation_type'], 'start_before');
    });
  });

  // The reaction list arrives as a bare array from a plain BaseViewSet, but
  // the same parser is pointed at the comment reaction route too.
  group('IssueService.parseReactions', () {
    test('reads a bare array', () {
      final parsed = IssueService.parseReactions([
        {'id': 'r1', 'reaction': '128077', 'actor': 'u1'},
        {'id': 'r2', 'reaction': '128064', 'actor': 'u2'},
      ]);
      expect(parsed.length, 2);
      expect(parsed.first.reaction, '128077');
      expect(parsed.first.emoji, '\u{1F44D}');
    });

    test('reads a paginated envelope', () {
      final parsed = IssueService.parseReactions({
        'results': [
          {'id': 'r1', 'reaction': '9992', 'actor': 'u1'},
        ],
      });
      expect(parsed.single.reaction, '9992');
    });

    test('returns empty for null and for a shape it does not know', () {
      expect(IssueService.parseReactions(null), isEmpty);
      expect(IssueService.parseReactions('nope'), isEmpty);
      expect(IssueService.parseReactions({'detail': 'not found'}), isEmpty);
    });

    test('skips entries that are not objects', () {
      final parsed = IssueService.parseReactions([
        'garbage',
        {'id': 'r1', 'reaction': '128077'},
      ]);
      expect(parsed.length, 1);
    });
  });

  group('IssueService.parseEstimatePoints', () {
    // The endpoint applies no ordering, and an unordered scale reads as
    // nonsense. `key` is the field the scale is authored in.
    test('orders the scale by key, not by arrival', () {
      final parsed = IssueService.parseEstimatePoints([
        {'id': 'e3', 'key': 2, 'value': '8'},
        {'id': 'e1', 'key': 0, 'value': '1'},
        {'id': 'e2', 'key': 1, 'value': '3'},
      ]);
      expect(parsed.map((e) => e.value), ['1', '3', '8']);
    });

    // A project with no estimate system configured gets a 200 with [], which
    // is the signal for the UI to hide the control rather than show it empty.
    test('returns empty for a project with no estimate scale', () {
      expect(IssueService.parseEstimatePoints([]), isEmpty);
    });

    test('reads a key that arrived as a string', () {
      final parsed = IssueService.parseEstimatePoints([
        {'id': 'e2', 'key': '1', 'value': 'M'},
        {'id': 'e1', 'key': '0', 'value': 'S'},
      ]);
      expect(parsed.map((e) => e.value), ['S', 'M']);
    });

    test('keeps the description when the scale carries one', () {
      final parsed = IssueService.parseEstimatePoints([
        {'id': 'e1', 'key': 0, 'value': 'S', 'description': 'Small'},
      ]);
      expect(parsed.single.description, 'Small');
    });

    test('returns empty for shapes that are not a list', () {
      expect(IssueService.parseEstimatePoints(null), isEmpty);
      expect(IssueService.parseEstimatePoints({'error': 'forbidden'}), isEmpty);
    });
  });

  group('IssueService server rules mirrored client-side', () {
    // The relation kinds offered for creation must all be ones the server's
    // get_actual_relation understands.
    test('offers exactly the four relation kinds, with labels', () {
      expect(IssueService.relationKinds.keys,
          containsAll(['blocking', 'blocked_by', 'duplicate', 'relates_to']));
      expect(IssueService.relationKinds.length, 4);
      expect(IssueService.relationKinds['blocked_by'], 'Blocked by');
    });

    // IssueArchiveViewSet.archive 400s anything outside these two groups, so
    // the UI checks the same rule to explain rather than fail.
    test('archiving is limited to completed and cancelled state groups', () {
      expect(IssueService.archivableStateGroups, {'completed', 'cancelled'});
      expect(IssueService.archivableStateGroups.contains('started'), isFalse);
      expect(IssueService.archivableStateGroups.contains('backlog'), isFalse);
    });
  });
}
