import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/comment.dart';
import 'package:plane_mobile/models/reaction.dart';

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

  // IssueCommentSerializer nests comment_reactions, so the whole feed's
  // reactions arrive with the comment list — one request, not one per card.
  group('Comment reactions', () {
    test('reads the embedded comment_reactions', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'comment_html': '<p>Nice</p>',
        'comment_reactions': [
          {
            'id': 'r1',
            'reaction': '128077',
            'actor': 'user-1',
            'display_name': 'Ada',
          },
          {'id': 'r2', 'reaction': '128077', 'actor': 'user-2'},
        ],
      });
      expect(comment.reactions.length, 2);
      expect(comment.reactions.first.emoji, '\u{1F44D}');
      expect(comment.reactions.first.displayName, 'Ada');
    });

    test('defaults to none when the server sends no reactions key', () {
      expect(Comment.fromJson({'id': 'c1'}).reactions, isEmpty);
    });

    test('ignores entries that are not objects', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'comment_reactions': [
          'garbage',
          {'id': 'r1', 'reaction': '9992'},
        ],
      });
      expect(comment.reactions.length, 1);
    });

    // Reacting answers with the reaction row, not the comment, so the card is
    // rebuilt from what the caller already holds.
    test('copyWithReactions swaps reactions and keeps everything else', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'comment_html': '<p>Body</p>',
        'actor': 'user-1',
        'edited_at': '2025-03-02T12:00:00Z',
      });
      final updated = comment.copyWithReactions([
        Reaction(id: 'r1', reaction: '128064', actor: 'user-2'),
      ]);

      expect(updated.reactions.single.reaction, '128064');
      expect(updated.id, comment.id);
      expect(updated.commentHtml, comment.commentHtml);
      expect(updated.actor, comment.actor);
      expect(updated.editedAt, comment.editedAt);
      expect(updated.createdAt, comment.createdAt);
      // The original is untouched, which is what makes the optimistic revert
      // in the detail screen work.
      expect(comment.reactions, isEmpty);
    });
  });
}
