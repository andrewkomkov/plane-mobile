import '../config/api_client.dart';
import '../models/inbox_issue.dart';

class InboxService {
  static Future<String?> getInboxId(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/inboxes/',
    );
    final data = response.data;
    List list;
    if (data is Map && data.containsKey('results')) {
      list = data['results'] as List;
    } else if (data is List) {
      list = data;
    } else {
      return null;
    }
    if (list.isEmpty) return null;
    return list.first['id']?.toString();
  }

  static Future<List<InboxIssue>> getInboxIssues(
    String workspaceSlug,
    String projectId,
    String inboxId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/inboxes/$inboxId/inbox-issues/',
    );
    final data = response.data;
    List list;
    if (data is Map && data.containsKey('results')) {
      list = data['results'] as List;
    } else if (data is List) {
      list = data;
    } else {
      return [];
    }
    return list.map((e) => InboxIssue.fromJson(e)).toList();
  }

  static Future<InboxIssue> updateInboxIssue(
    String workspaceSlug,
    String projectId,
    String inboxId,
    String inboxIssueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/inboxes/$inboxId/inbox-issues/$inboxIssueId/',
      data: data,
    );
    return InboxIssue.fromJson(response.data);
  }
}
