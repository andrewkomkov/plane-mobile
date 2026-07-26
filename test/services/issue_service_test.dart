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
}
