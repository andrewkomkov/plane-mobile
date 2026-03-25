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
}
