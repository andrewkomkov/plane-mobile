import '../config/api_client.dart';
import '../models/comment.dart';

class CommentService {
  static Future<List<Comment>> getComments(
      String workspaceSlug, String projectId, String issueId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/comments/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Comment.fromJson(e)).toList();
  }

  static Future<Comment> addComment(
      String workspaceSlug, String projectId, String issueId, String html) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/comments/',
      data: {'comment_html': html},
    );
    return Comment.fromJson(response.data);
  }
}
