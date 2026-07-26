import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/module.dart';

void main() {
  group('Module.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'mod-1',
        'name': 'Auth Module',
        'description': 'Authentication features',
        'status': 'planned',
        'start_date': '2025-01-01',
        'target_date': '2025-03-01',
        'lead': 'user-1',
        'members': ['user-1', 'user-2'],
        'total_issues': 20,
        'completed_issues': 5,
        'created_at': '2024-12-01T00:00:00Z',
      };

      final module = Module.fromJson(json);

      expect(module.id, 'mod-1');
      expect(module.name, 'Auth Module');
      expect(module.description, 'Authentication features');
      expect(module.status, 'planned');
      expect(module.startDate, '2025-01-01');
      expect(module.targetDate, '2025-03-01');
      expect(module.lead, 'user-1');
      expect(module.members, ['user-1', 'user-2']);
      expect(module.totalIssues, 20);
      expect(module.completedIssues, 5);
    });

    test('handles missing fields with defaults', () {
      final module = Module.fromJson(<String, dynamic>{});

      expect(module.id, '');
      expect(module.name, '');
      expect(module.description, isNull);
      expect(module.status, isNull);
      expect(module.startDate, isNull);
      expect(module.targetDate, isNull);
      expect(module.lead, isNull);
      expect(module.members, isEmpty);
      expect(module.totalIssues, 0);
      expect(module.completedIssues, 0);
    });

    test('handles null members list', () {
      final json = {'members': null};
      final module = Module.fromJson(json);
      expect(module.members, isEmpty);
    });
  });

  group('Module.progress', () {
    test('returns ratio when totalIssues > 0', () {
      final module = Module(
        id: '1',
        name: 'M1',
        totalIssues: 8,
        completedIssues: 2,
        createdAt: DateTime(2025),
      );
      expect(module.progress, closeTo(0.25, 0.001));
    });

    test('returns 0 when totalIssues is 0', () {
      final module = Module(
        id: '1',
        name: 'M1',
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(module.progress, 0);
    });
  });

  group('Module archive state', () {
    Module build({String? status, String? archivedAt}) => Module.fromJson({
          'id': '1',
          'name': 'M1',
          'status': status,
          'total_issues': 0,
          'completed_issues': 0,
          if (archivedAt != null) 'archived_at': archivedAt,
        });

    test('reads archived_at, which only archived-modules/ ever sends', () {
      final module =
          build(status: 'completed', archivedAt: '2025-03-04T10:00:00Z');
      expect(module.isArchived, isTrue);
      expect(module.archivedAt, DateTime.utc(2025, 3, 4, 10));
    });

    test('a module from the live list is not archived', () {
      expect(build(status: 'in-progress').isArchived, isFalse);
      expect(build(status: 'in-progress').archivedAt, isNull);
    });

    // The server answers 400 "Only completed or cancelled modules can be
    // archived", so those two statuses are the whole of the allowed set.
    test('only a completed or cancelled module can be archived', () {
      expect(build(status: 'completed').canArchive, isTrue);
      expect(build(status: 'cancelled').canArchive, isTrue);
      expect(build(status: 'in-progress').canArchive, isFalse);
      expect(build(status: 'planned').canArchive, isFalse);
      expect(build(status: 'paused').canArchive, isFalse);
      expect(build(status: 'backlog').canArchive, isFalse);
      expect(build().canArchive, isFalse);
    });

    test('an already archived module cannot be archived again', () {
      expect(
        build(status: 'completed', archivedAt: '2025-03-04T10:00:00Z')
            .canArchive,
        isFalse,
      );
    });
  });
}
