import '../config/api_client.dart';
import '../models/issue.dart';

/// An archived work item, paired with the moment it was archived.
///
/// [Issue] has no `archivedAt` field, and gaining one would mean every screen
/// that parses a work item carrying a value that is null on all but this one
/// endpoint. The timestamp is what makes an archived row worth reading, so it
/// rides alongside the issue instead.
class ArchivedIssue {
  final Issue issue;

  /// Null only if the server sent something unparseable — `archived-issues/`
  /// filters on `archived_at__isnull=False`, so every row has one.
  final DateTime? archivedAt;

  const ArchivedIssue({required this.issue, this.archivedAt});

  factory ArchivedIssue.fromJson(Map<String, dynamic> json) => ArchivedIssue(
        issue: Issue.fromJson(json),
        archivedAt: DateTime.tryParse(json['archived_at']?.toString() ?? ''),
      );
}

/// Reads the archived work items of a project.
///
/// Separate from `IssueService` on purpose: that service is the live work-item
/// surface and every one of its calls is scoped to `issues/`, which excludes
/// archived rows. `archived-issues/` is a different queryset behind a different
/// view (`IssueArchiveViewSet`), and keeping it here means nothing on the live
/// path has to grow an "and also archived" branch.
class ArchivedIssueService {
  /// Archived work items, newest first.
  ///
  /// Shares `issues/`'s paginated envelope — the view calls the same
  /// `self.paginate` — so the response is `{results: [...], next_cursor: ...}`
  /// rather than a bare list. The rows come from `issue_on_results`, which
  /// includes `archived_at` and the internal API's id spellings
  /// (`state_id`, `assignee_ids`, `label_ids`) that `Issue.fromJson` reads.
  ///
  /// Epics are excluded server-side, as they are on the live list.
  static Future<List<ArchivedIssue>> getArchivedIssues(
    String workspaceSlug,
    String projectId, {
    int perPage = 100,
    String orderBy = '-created_at',
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/archived-issues/',
      queryParameters: {'per_page': perPage, 'order_by': orderBy},
    );
    return parseArchivedIssues(response.data);
  }

  /// Split out so the envelope handling is testable without a server.
  ///
  /// Grouping is never requested here, so `results` is a flat list; a grouped
  /// response would nest it under the group keys instead, which is why the
  /// non-list case returns empty rather than guessing.
  static List<ArchivedIssue> parseArchivedIssues(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ArchivedIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
