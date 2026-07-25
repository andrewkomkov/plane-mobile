import '../config/api_client.dart';
import '../models/issue.dart';
import '../models/state.dart';
import '../models/activity.dart';
import '../models/link.dart';

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

  static Future<void> deleteIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
    );
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

  static Future<List<Issue>> getSubIssues(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/sub-issues/',
    );
    if (response.data is List) {
      return (response.data as List).map((e) => Issue.fromJson(e)).toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getIssueRelations(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-relations/',
    );
    if (response.data is List) {
      return (response.data as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  static Future<List<Activity>> getActivities(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/activities/',
      queryParameters: {'expand': 'actor_detail'},
    );
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    if (list is List) {
      return list.map((e) => Activity.fromJson(e)).toList();
    }
    return [];
  }

  static Future<List<IssueLink>> getLinks(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-links/',
    );
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    if (list is List) {
      return list.map((e) => IssueLink.fromJson(e)).toList();
    }
    return [];
  }

  static Future<IssueLink> addLink(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-links/',
      data: data,
    );
    return IssueLink.fromJson(response.data);
  }

  static Future<IssueState> createState(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/states/',
      data: data,
    );
    return IssueState.fromJson(response.data);
  }

  static Future<IssueState> updateState(
    String workspaceSlug,
    String projectId,
    String stateId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/states/$stateId/',
      data: data,
    );
    return IssueState.fromJson(response.data);
  }

  static Future<void> deleteState(
    String workspaceSlug,
    String projectId,
    String stateId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/states/$stateId/',
    );
  }
}
