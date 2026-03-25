import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'id': 'comment-1',
        'comment_html': '<p>Looks good!</p>',
        'actor_detail': {'display_name': 'Alice'},
        'created_by': 'user-1',
        'created_at': '2025-03-01T10:00:00Z',
        'updated_at': '2025-03-01T11:00:00Z',
      };

      final comment = Comment.fromJson(json);

      expect(comment.id, 'comment-1');
      expect(comment.commentHtml, '<p>Looks good!</p>');
      expect(comment.actorDetail, 'Alice');
      expect(comment.createdBy, 'user-1');
      expect(comment.createdAt, DateTime.utc(2025, 3, 1, 10));
      expect(comment.updatedAt, DateTime.utc(2025, 3, 1, 11));
    });

    test('falls back to created_by when actor_detail is null', () {
      final json = {
        'id': 'comment-2',
        'created_by': 'user-uuid',
      };
      final comment = Comment.fromJson(json);
      expect(comment.actorDetail, 'user-uuid');
    });

    test('handles empty JSON', () {
      final comment = Comment.fromJson(<String, dynamic>{});

      expect(comment.id, '');
      expect(comment.commentHtml, isNull);
      expect(comment.actorDetail, isNull);
      expect(comment.createdBy, isNull);
    });

    test('handles null actor_detail and null created_by', () {
      final json = {
        'id': 'c3',
        'actor_detail': null,
        'created_by': null,
      };
      final comment = Comment.fromJson(json);
      expect(comment.actorDetail, isNull);
    });
  });
}
