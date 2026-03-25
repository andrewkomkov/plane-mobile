import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/cycle.dart';

void main() {
  group('Cycle.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'cycle-1',
        'name': 'Sprint 1',
        'description': 'First sprint',
        'start_date': '2025-01-01',
        'end_date': '2025-01-14',
        'owned_by': 'user-1',
        'status': 'current',
        'total_issues': 10,
        'completed_issues': 7,
        'created_at': '2024-12-15T00:00:00Z',
      };

      final cycle = Cycle.fromJson(json);

      expect(cycle.id, 'cycle-1');
      expect(cycle.name, 'Sprint 1');
      expect(cycle.description, 'First sprint');
      expect(cycle.startDate, '2025-01-01');
      expect(cycle.endDate, '2025-01-14');
      expect(cycle.ownedBy, 'user-1');
      expect(cycle.status, 'current');
      expect(cycle.totalIssues, 10);
      expect(cycle.completedIssues, 7);
    });

    test('handles missing fields with defaults', () {
      final cycle = Cycle.fromJson(<String, dynamic>{});

      expect(cycle.id, '');
      expect(cycle.name, '');
      expect(cycle.description, isNull);
      expect(cycle.startDate, isNull);
      expect(cycle.endDate, isNull);
      expect(cycle.ownedBy, isNull);
      expect(cycle.status, isNull);
      expect(cycle.totalIssues, 0);
      expect(cycle.completedIssues, 0);
    });
  });

  group('Cycle.progress', () {
    test('returns ratio when totalIssues > 0', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        totalIssues: 10,
        completedIssues: 3,
        createdAt: DateTime(2025),
      );
      expect(cycle.progress, closeTo(0.3, 0.001));
    });

    test('returns 0 when totalIssues is 0', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.progress, 0);
    });
  });

  group('Cycle.computedStatus', () {
    test('returns explicit status when set', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        status: 'current',
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'current');
    });

    test('returns draft when dates are null', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        startDate: null,
        endDate: null,
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'draft');
    });

    test('returns upcoming when start date is in the future', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        startDate: '2099-01-01',
        endDate: '2099-12-31',
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'upcoming');
    });

    test('returns completed when end date is in the past', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        startDate: '2020-01-01',
        endDate: '2020-12-31',
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'completed');
    });

    test('returns current when now is between start and end', () {
      final now = DateTime.now();
      final start =
          now.subtract(const Duration(days: 5)).toIso8601String().split('T')[0];
      final end =
          now.add(const Duration(days: 5)).toIso8601String().split('T')[0];
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        startDate: start,
        endDate: end,
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'current');
    });

    test('returns draft when status is empty string', () {
      final cycle = Cycle(
        id: '1',
        name: 'S1',
        status: '',
        startDate: null,
        endDate: null,
        totalIssues: 0,
        completedIssues: 0,
        createdAt: DateTime(2025),
      );
      expect(cycle.computedStatus, 'draft');
    });
  });
}
