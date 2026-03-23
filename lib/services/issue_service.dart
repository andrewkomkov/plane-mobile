import '../config/api_client.dart';
import '../models/issue.dart';
import '../models/state.dart';

class IssueService {
  static Future<Map<String, dynamic>> getIssues(
    String workspaceSlug,
    String projectId, {
    String? cursor,
    int perPage = 50,
    String orderBy = '-created_at',
  }) async {
    final dio = await ApiClient.getInstance();
    final params = <String, dynamic>{
      'per_page': perPage,
      'order_by': orderBy,
    };
    if (cursor != null) params['cursor'] = cursor;

    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/',
      queryParameters: params,
    );

    final data = response.data;
    final issues = (data['results'] as List?)
            ?.map((e) => Issue.fromJson(e))
            .toList() ??
        [];

    return {
      'issues': issues,
      'next_cursor': data['next_cursor'],
      'next_page_results': data['next_page_results'] ?? false,
      'total_results': data['total_results'] ?? 0,
    };
  }

  static Future<Issue> getIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
    );
    return Issue.fromJson(response.data);
  }

  static Future<Issue> createIssue(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/',
      data: data,
    );
    return Issue.fromJson(response.data);
  }

  static Future<Issue> updateIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
      data: data,
    );
    return Issue.fromJson(response.data);
  }

  static Future<List<IssueState>> getStates(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/states/',
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => IssueState.fromJson(e)).toList();
    }
    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => IssueState.fromJson(e))
          .toList();
    }
    return [];
  }
}
