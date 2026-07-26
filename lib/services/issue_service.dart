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

  /// Renames relation keys to what Plane's internal write serializer expects.
  ///
  /// `IssueCreateSerializer` declares `state_id`, `parent_id`, `label_ids` and
  /// `assignee_ids` (see `plane/app/serializers/issue.py`). A payload using the
  /// plain names is not rejected — the serialiser simply ignores the unknown
  /// keys — so changing a state or an assignee would appear to succeed and
  /// then quietly do nothing. Translating in one place keeps every call site
  /// speaking the model's own field names.
  static Map<String, dynamic> _toWritePayload(Map<String, dynamic> data) {
    const renames = {
      'state': 'state_id',
      'parent': 'parent_id',
      'labels': 'label_ids',
      'assignees': 'assignee_ids',
    };
    final out = <String, dynamic>{};
    data.forEach((key, value) => out[renames[key] ?? key] = value);
    return out;
  }

  static Future<Issue> createIssue(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/',
      data: _toWritePayload(data),
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
      data: _toWritePayload(data),
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
  /// This lives only on Plane's internal API, which used to be unreachable —
  /// it authenticates by session cookie and ignores the `X-Api-Key` this app
  /// sends, and the v1 API the app was pinned to has no sub-issue route at all.
  /// It works now because requests go through the proxy in plane-mobile-api,
  /// which exchanges the token for a real session. Verified against the live
  /// instance.
  static Future<List<Issue>> getSubIssues(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/sub-issues/',
    );
    // The internal API answers with an object, not a list:
    // {"sub_issues": [...], "state_distribution": {...}}.
    final data = response.data;
    if (data is Map && data['sub_issues'] is List) {
      return (data['sub_issues'] as List)
          .map((e) => Issue.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => Issue.fromJson(e)).toList();
    }
    return [];
  }

  /// Relations (blocking / blocked by / duplicate / relates to) on [issueId].
  ///
  /// Reachable through the proxy, like [getSubIssues]. Two bugs had to be
  /// fixed before it could work: the path was `issue-relations/`, plural,
  /// which is a route on neither API, and the response is not a list — the
  /// server returns an object keyed by relation kind
  /// (`{"blocking": [...], "blocked_by": [...], ...}`), so the old `is List`
  /// check never matched and the method always returned empty.
  ///
  /// The write path (POST `issue-relation/`, `remove-relation/`) is now
  /// callable too but is not implemented yet — see task #14.
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
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/history/',
      // activity_type is not optional here, whatever the route suggests.
      // Without it Plane falls through to a branch that sorts unserialised
      // model instances as if they were dicts (`instance["created_at"]` in
      // plane/app/views/issue/activity.py), which throws and returns a 500.
      // The property feed already embeds actor_detail, and comments are
      // fetched separately by CommentService, so this is the branch we want.
      queryParameters: {'activity_type': 'issue-property'},
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
