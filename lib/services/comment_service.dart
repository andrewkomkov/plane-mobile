import '../config/api_client.dart';
import '../models/comment.dart';

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
}
