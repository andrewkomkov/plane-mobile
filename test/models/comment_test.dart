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

    // The token API sends the actor as a bare id and no actor_detail at all,
    // so the id is the only identity that reliably arrives.
    test('reads a bare actor id', () {
      final comment = Comment.fromJson({'id': 'c4', 'actor': 'user-7'});
      expect(comment.actor, 'user-7');
    });

    test('reads an id out of an expanded actor object', () {
      final comment = Comment.fromJson({
        'id': 'c5',
        'actor': {'id': 'user-8', 'display_name': 'Bob'},
      });
      expect(comment.actor, 'user-8');
    });

    test('parses edited_at when the server has stamped an edit', () {
      final comment = Comment.fromJson({
        'id': 'c6',
        'edited_at': '2025-03-01T12:00:00Z',
      });
      expect(comment.editedAt, DateTime.utc(2025, 3, 1, 12));
    });

    test('leaves editedAt null for a comment that was never edited', () {
      final comment = Comment.fromJson({'id': 'c7', 'edited_at': null});
      expect(comment.editedAt, isNull);
    });
  });

  group('Comment.isAuthoredBy', () {
    test('matches on actor', () {
      final comment = Comment.fromJson({'id': 'c1', 'actor': 'user-1'});
      expect(comment.isAuthoredBy('user-1'), isTrue);
      expect(comment.isAuthoredBy('user-2'), isFalse);
    });

    // A comment made through an integration can carry created_by without
    // actor, so both are checked.
    test('matches on created_by when actor is absent', () {
      final comment = Comment.fromJson({'id': 'c2', 'created_by': 'user-3'});
      expect(comment.isAuthoredBy('user-3'), isTrue);
    });

    test('is false when the current user is unknown', () {
      final comment = Comment.fromJson({'id': 'c3', 'actor': 'user-1'});
      expect(comment.isAuthoredBy(null), isFalse);
      expect(comment.isAuthoredBy(''), isFalse);
    });

    // An unattributed comment must not become editable by whoever is looking.
    test('is false when the comment has no author at all', () {
      final comment = Comment.fromJson({'id': 'c4'});
      expect(comment.isAuthoredBy('user-1'), isFalse);
    });
  });
}
