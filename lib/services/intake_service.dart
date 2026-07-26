import '../config/api_client.dart';
import '../models/intake_issue.dart';

/// Intake — the per-project triage queue for work items submitted from outside
/// the project. Plane shipped this as "Inbox" and renamed it to "Intake".
///
/// These are the v1 routes from `plane/api/urls/intake.py`, which is the
/// surface that matters: setup stores an API token for both sign-in paths, so
/// [ApiClient] is always based at `{host}/api/v1` and the internal `/api`
/// routes are unreachable in practice.
///
/// Two things about the current routes are worth knowing before editing them:
///
/// 1. There is no intake id in any of these paths. The old code fetched the
///    project's inbox first and threaded its id through every subsequent call.
///    That round-trip is gone, and it was not merely redundant — `inboxes/`
///    has no v1 route at all, so that lookup was returning 404 and taking the
///    whole feature down with it. A project has exactly one Intake and the
///    server resolves it from `project_id` itself. Only the internal API ever
///    exposed an `intakes/` collection; do not reintroduce a call to it.
///
/// 2. The detail routes are keyed by the **work item** id, not by the
///    IntakeIssue row id — `plane/api/views/intake.py` declares them
///    `<uuid:issue_id>` and looks the object up with `issue_id=`. Passing
///    `IntakeIssue.id` here 404s, so callers must pass [IntakeIssue.issueId].
class IntakeService {
  static Future<List<IntakeIssue>> getIntakeIssues(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/',
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
    return list.map((e) => IntakeIssue.fromJson(e)).toList();
  }

  static Future<IntakeIssue> getIntakeIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/$issueId/',
    );
    return IntakeIssue.fromJson(response.data);
  }

  /// Triages an entry. Pass `{'status': 1}` to accept, `-1` to decline, `0`
  /// with a `snoozed_till` timestamp to snooze, `2` with `duplicate_to` to mark
  /// a duplicate. Fields of the work item itself go under an `issue` key.
  static Future<IntakeIssue> updateIntakeIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/$issueId/',
      data: data,
    );
    return IntakeIssue.fromJson(response.data);
  }
}
