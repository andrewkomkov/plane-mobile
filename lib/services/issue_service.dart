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
    final issues =
        (data['results'] as List?)?.map((e) => Issue.fromJson(e)).toList() ??
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

  /// Sub-issues of [issueId].
  ///
  /// UNREACHABLE ON THE CURRENT TRANSPORT. `sub-issues/` exists only on Plane's
  /// internal app API (`/api`), which authenticates with a session cookie and
  /// rejects the `X-Api-Key` header this app sends. The app authenticates with
  /// an API token and so talks to `/api/v1`, whose work-item route table has no
  /// sub-issue endpoint at all. This therefore 404s in production; callers must
  /// treat a failure as "unknown", not as "none".
  ///
  /// Linking a child to a parent still works, because that is a plain `parent`
  /// field on the work item and v1 supports PATCHing it.
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

  /// Relations (blocking / blocked by / duplicate / relates to) on [issueId].
  ///
  /// UNREACHABLE ON THE CURRENT TRANSPORT, for the same reason as
  /// [getSubIssues]: issue relations live only on the internal app API, and the
  /// v1 API this app authenticates against has no relation routes — neither
  /// read nor write. The write path asked for in the coverage doc (POST
  /// `issue-relation/` and `remove-relation/`) is therefore not implemented,
  /// because there is nothing on this transport to call.
  ///
  /// Two bugs in the previous version of this method are fixed anyway, so that
  /// it works the moment the transport does. The path was `issue-relations/`,
  /// plural, which is not a route on either API. And the response is not a
  /// list: the server returns an object keyed by relation kind
  /// (`{"blocking": [...], "blocked_by": [...], ...}`), so the old `is List`
  /// check could never match and the method always returned empty.
  static Future<List<Map<String, dynamic>>> getIssueRelations(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-relation/',
    );
    return parseIssueRelations(response.data);
  }

  /// Flattens the server's kind-keyed relation object into one list, tagging
  /// each entry with the kind it was filed under.
  ///
  /// Kept separate from the request so the shape can be tested without a server.
  static List<Map<String, dynamic>> parseIssueRelations(dynamic data) {
    if (data is! Map) return [];
    final out = <Map<String, dynamic>>[];
    data.forEach((kind, entries) {
      if (entries is! List) return;
      for (final entry in entries) {
        if (entry is! Map) continue;
        out.add(<String, dynamic>{
          ...Map<String, dynamic>.from(entry),
          // The rows carry their own relation_type, but only the key is
          // guaranteed present, so the key wins as the authoritative kind.
          'relation_type': kind.toString(),
        });
      }
    });
    return out;
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
