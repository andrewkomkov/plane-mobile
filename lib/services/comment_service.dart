import '../config/api_client.dart';
import '../models/comment.dart';
import '../models/reaction.dart';
import 'issue_service.dart';

class CommentService {
  static String _base(String workspaceSlug, String projectId, String issueId) =>
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/comments/';

  static Future<List<Comment>> getComments(
      String workspaceSlug, String projectId, String issueId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(_base(workspaceSlug, projectId, issueId));
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Comment.fromJson(e)).toList();
  }

  static Future<Comment> addComment(String workspaceSlug, String projectId,
      String issueId, String html) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      _base(workspaceSlug, projectId, issueId),
      data: {'comment_html': html},
    );
    return Comment.fromJson(response.data);
  }

  /// Edits the body of an existing comment.
  ///
  /// The server takes the edit through a create-shaped serialiser but responds
  /// with the full comment, so the parsed result is safe to swap straight into
  /// the list without a refetch. It also stamps `edited_at` itself, and only
  /// when the HTML actually differs.
  ///
  /// Authorisation is the caller's job — see [canModify].
  static Future<Comment> updateComment(
    String workspaceSlug,
    String projectId,
    String issueId,
    String commentId,
    String html,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '${_base(workspaceSlug, projectId, issueId)}$commentId/',
      data: {'comment_html': html},
    );
    return Comment.fromJson(response.data);
  }

  static Future<void> deleteComment(
    String workspaceSlug,
    String projectId,
    String issueId,
    String commentId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('${_base(workspaceSlug, projectId, issueId)}$commentId/');
  }

  /// Whether to offer edit and delete on [comment] to the user [currentUserId].
  ///
  /// This is deliberately *stricter* than the server it talks to. The token API
  /// guards comment edit and delete with `ProjectLitePermission` alone, which
  /// means any active member of the project may rewrite or destroy anybody
  /// else's comment. The internal API is the one that gets this right, with
  /// `allow_permission(allowed_roles=[ADMIN], creator=True, model=IssueComment)`
  /// — author, or project admin.
  ///
  /// Authorship is the intersection of the two, so gating on it can never
  /// produce a 403, and it does not hand every member a silent edit button over
  /// their colleagues' words. The admin half of the internal rule is not
  /// implemented because it cannot be evaluated here: the token API's project
  /// members endpoint returns bare user records with no `role` field, so the
  /// current user's project role is simply not knowable on this transport.
  static bool canModify(Comment comment, String? currentUserId) =>
      comment.isAuthoredBy(currentUserId);

  // --- Comment reactions (#7) ---

  /// Comment reactions hang off the project, not off the work item.
  ///
  /// The route is `projects/<project_id>/comments/<comment_id>/reactions/` —
  /// there is no `issues/<issue_id>/` segment in it, unlike every other comment
  /// route in this file. Building it from [_base] by appending would produce a
  /// path that 404s.
  static String _reactionBase(
          String workspaceSlug, String projectId, String commentId) =>
      '/workspaces/$workspaceSlug/projects/$projectId/comments/$commentId/reactions/';

  /// Reactions on a comment.
  ///
  /// Rarely needed: the comment list already embeds them (see
  /// `Comment.reactions`). This is for re-reading one comment's reactions
  /// without refetching the feed.
  static Future<List<Reaction>> getReactions(
    String workspaceSlug,
    String projectId,
    String commentId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response =
        await dio.get(_reactionBase(workspaceSlug, projectId, commentId));
    return IssueService.parseReactions(response.data);
  }

  /// Adds [reactionCode] — a decimal code point string, not an emoji — to a
  /// comment. See [Reaction.emoji].
  static Future<Reaction> addReaction(
    String workspaceSlug,
    String projectId,
    String commentId,
    String reactionCode,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      _reactionBase(workspaceSlug, projectId, commentId),
      data: {'reaction': reactionCode},
    );
    return Reaction.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// Removes the current user's [reactionCode] from a comment. Keyed by the
  /// code, and scoped server-side to the requesting user, as for work items.
  static Future<void> removeReaction(
    String workspaceSlug,
    String projectId,
    String commentId,
    String reactionCode,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '${_reactionBase(workspaceSlug, projectId, commentId)}$reactionCode/',
    );
  }
}
