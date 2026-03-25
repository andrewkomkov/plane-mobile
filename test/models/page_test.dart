import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/page.dart';

void main() {
  group('PlanePage.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'page-1',
        'name': 'Sprint Notes',
        'description_html': '<p>Notes here</p>',
        'owned_by': 'user-1',
        'access': 1,
        'is_locked': true,
        'archived_at': '2025-05-01T00:00:00Z',
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-02-01T00:00:00Z',
      };

      final page = PlanePage.fromJson(json);

      expect(page.id, 'page-1');
      expect(page.name, 'Sprint Notes');
      expect(page.descriptionHtml, '<p>Notes here</p>');
      expect(page.ownedBy, 'user-1');
      expect(page.access, 1);
      expect(page.isLocked, isTrue);
      expect(page.archivedAt, DateTime.utc(2025, 5, 1));
      expect(page.createdAt, DateTime.utc(2025, 1, 1));
      expect(page.updatedAt, DateTime.utc(2025, 2, 1));
    });

    test('handles missing fields with defaults', () {
      final page = PlanePage.fromJson(<String, dynamic>{});

      expect(page.id, '');
      expect(page.name, '');
      expect(page.descriptionHtml, isNull);
      expect(page.ownedBy, isNull);
      expect(page.access, 0);
      expect(page.isLocked, isFalse);
      expect(page.archivedAt, isNull);
    });

    test('handles null archived_at', () {
      final json = {'archived_at': null};
      final page = PlanePage.fromJson(json);
      expect(page.archivedAt, isNull);
    });
  });
}
