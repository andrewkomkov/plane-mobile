import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/comment.dart';
import 'package:plane_mobile/services/comment_service.dart';

void main() {
  // The point of these is that the edit/delete affordance is never offered for
  // a comment the user did not write. The token API would in fact allow it —
  // it guards comment edit with ProjectLitePermission alone, so any project
  // member may rewrite anyone's comment — which is exactly why the client has
  // to be the stricter of the two.
  group('CommentService.canModify', () {
    Comment comment({String? actor, String? createdBy}) => Comment.fromJson({
          'id': 'c1',
          if (actor != null) 'actor': actor,
          if (createdBy != null) 'created_by': createdBy,
        });

    test('allows the author', () {
      expect(CommentService.canModify(comment(actor: 'me'), 'me'), isTrue);
    });

    test('refuses somebody else', () {
      expect(CommentService.canModify(comment(actor: 'them'), 'me'), isFalse);
    });

    test('allows the author identified only by created_by', () {
      expect(CommentService.canModify(comment(createdBy: 'me'), 'me'), isTrue);
    });

    test('refuses when the current user is not yet known', () {
      // The identity load is async; until it lands nothing is offered, rather
      // than everything being offered.
      expect(CommentService.canModify(comment(actor: 'me'), null), isFalse);
    });

    test('refuses an unattributed comment', () {
      expect(CommentService.canModify(comment(), 'me'), isFalse);
    });
  });
}
