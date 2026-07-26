import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/view.dart';

void main() {
  group('PlaneView', () {
    // The bug this pins: the model read `query_data`, which is not a field on
    // Plane's IssueView. Every saved view therefore arrived with an empty
    // filter set, and the detail screen listed the whole project instead of
    // the subset the view names. An empty map looks exactly like "no filters",
    // so nothing ever reported it.
    test('reads the filter set from the field the server actually sends', () {
      final view = PlaneView.fromJson({
        'id': 'v1',
        'name': 'My bugs',
        'filters': {
          'state': ['s1', 's2'],
          'priority': ['urgent'],
        },
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(view.queryData['state'], ['s1', 's2']);
      expect(view.queryData['priority'], ['urgent']);
    });

    test('a view with no filters yields an empty set, not null', () {
      final view = PlaneView.fromJson({'id': 'v1', 'name': 'All'});
      expect(view.queryData, isEmpty);
    });
  });
}
