import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/project.dart';

void main() {
  group('Project.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'proj-1',
        'name': 'My Project',
        'identifier': 'MP',
        'description': 'A test project',
        'cover_image_url': 'https://example.com/img.png',
        'emoji': '1f680',
        'network': 2,
        'total_members': 5,
        'is_member': true,
        'created_at': '2025-06-01T00:00:00Z',
      };

      final project = Project.fromJson(json);

      expect(project.id, 'proj-1');
      expect(project.name, 'My Project');
      expect(project.identifier, 'MP');
      expect(project.description, 'A test project');
      expect(project.coverImageUrl, 'https://example.com/img.png');
      expect(project.emoji, '1f680');
      expect(project.network, 2);
      expect(project.totalMembers, 5);
      expect(project.isMember, isTrue);
      expect(project.createdAt, DateTime.utc(2025, 6, 1));
    });

    test('handles missing fields with defaults', () {
      final project = Project.fromJson(<String, dynamic>{});

      expect(project.id, '');
      expect(project.name, '');
      expect(project.identifier, '');
      expect(project.description, isNull);
      expect(project.coverImageUrl, isNull);
      expect(project.emoji, isNull);
      expect(project.network, 0);
      expect(project.totalMembers, 0);
      expect(project.isMember, isFalse);
    });

    test('handles null values for optional fields', () {
      final json = {
        'description': null,
        'cover_image_url': null,
        'emoji': null,
      };
      final project = Project.fromJson(json);

      expect(project.description, isNull);
      expect(project.coverImageUrl, isNull);
      expect(project.emoji, isNull);
    });
  });
}
