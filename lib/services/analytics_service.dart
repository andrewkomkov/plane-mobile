import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/analytics.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// Builds the analytics screen's figures from the v1 API.
///
/// ## Why this sweeps instead of asking
///
/// Plane's analytics endpoints live on the internal app API and authenticate
/// by session cookie; this app authenticates by API token against `/api/v1/`,
/// where no analytics routes exist. See the header of `models/analytics.dart`
/// for the full trace. So the only server-side aggregate available is
/// `total_count` on the work-item list, and the breakdowns are counted here.
///
/// Counting here is only honest if it counts *everything*, which is what
/// [getWorkspaceAnalytics] does: it pages each project to exhaustion rather
/// than reading one page. Two things keep that affordable:
///
///   * `fields=id,state,priority,target_date` — the API's dynamic serialiser
///     drops everything else, so a work item costs about a hundred bytes over
///     the wire instead of the several kilobytes a full one costs.
///   * `per_page` at the server's maximum, so even a large project is a
///     handful of requests.
///
/// And a request budget keeps it bounded: the API token is rate limited to 60
/// requests a minute, so a workspace big enough to blow through
/// [_requestBudget] is reported as a partial scan instead of grinding against
/// the throttle. The screen then shows the coverage.
class AnalyticsService {
  /// Injected by tests in place of a real HTTP client.
  @visibleForTesting
  static Dio? debugClient;

  /// Injected by tests in place of the project list.
  @visibleForTesting
  static Future<List<Project>> Function(String slug)? debugProjectLoader;

  /// The server caps `per_page` at 1000 (`BasePaginator.paginate`). Asking for
  /// the cap is what keeps a 5,000-item project down to five requests.
  static const int _pageSize = 1000;

  /// Ceiling on requests for one refresh, chosen against the API token's
  /// 60/minute throttle. Leaves room for the project list and one states call
  /// per project without the sweep ever tripping the limiter.
  static const int _requestBudget = 45;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  static Future<List<Project>> _projects(String workspaceSlug) async {
    final loader = debugProjectLoader;
    if (loader != null) return loader(workspaceSlug);
    return ProjectService.getProjects(workspaceSlug);
  }

  /// Maps state UUID to state group for one project.
  ///
  /// Work items carry a state id, and state ids are per-project, so the group —
  /// the only axis worth aggregating across projects — has to be looked up.
  static Future<Map<String, String>> getStateGroups(
    String workspaceSlug,
    String projectId, {
    Dio? client,
  }) async {
    final dio = client ?? await _client();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/states/',
    );
    final data = response.data;
    final rows = data is Map ? (data['results'] ?? data['data']) : data;
    if (rows is! List) return {};
    return {
      for (final row in rows.whereType<Map>())
        (row['id'] ?? '').toString(): (row['group'] ?? 'backlog').toString(),
    };
  }

  /// Reads every work item in one project, following the cursor to the end.
  ///
  /// Returns the scan together with the number of requests it consumed, so the
  /// caller can hold the whole refresh to a budget. A project is cut short — and
  /// therefore reported as incomplete — only when the budget runs out.
  static Future<({ProjectScan scan, int requests})> scanProject(
    String workspaceSlug,
    Project project, {
    Dio? client,
    int requestBudget = _requestBudget,
  }) async {
    final dio = client ?? await _client();
    final stateGroups =
        await getStateGroups(workspaceSlug, project.id, client: dio);
    var requests = 1;

    final items = <ScannedWorkItem>[];
    var serverTotal = 0;
    String? cursor;

    while (requests < requestBudget) {
      final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/${project.id}/issues/',
        queryParameters: {
          'per_page': _pageSize,
          // Only the four columns the aggregation reads. The rest of the work
          // item — description HTML above all — would dominate the transfer.
          'fields': 'id,state,priority,target_date',
          if (cursor != null) 'cursor': cursor,
        },
      );
      requests++;

      final data = response.data;
      if (data is! Map) break;

      // `total_count` is a COUNT over the project, not over the page: the one
      // figure on this screen the database produced.
      serverTotal = (data['total_count'] as num?)?.toInt() ?? serverTotal;

      final rows = data['results'];
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          items.add(ScannedWorkItem.fromJson(
            Map<String, dynamic>.from(row),
            stateGroups,
          ));
        }
      }

      final hasMore = data['next_page_results'] == true;
      final next = data['next_cursor']?.toString();
      if (!hasMore || next == null || next.isEmpty || next == cursor) break;
      cursor = next;
    }

    return (
      scan: ProjectScan(
        projectId: project.id,
        projectName: project.name,
        serverTotal: serverTotal,
        items: items,
      ),
      requests: requests,
    );
  }

  /// Sweeps every project the user can see and folds the result.
  ///
  /// Projects are visited one at a time on purpose. Firing them in parallel
  /// would be faster but would burst straight into the 60/minute throttle, and
  /// a 429 mid-sweep costs more than the serialisation saves.
  ///
  /// A project that fails outright is skipped rather than failing the screen —
  /// one unreadable project should not blank out the other nine — but it still
  /// contributes its server total, so the coverage figure exposes the gap.
  static Future<WorkspaceAnalytics> getWorkspaceAnalytics(
    String workspaceSlug, {
    DateTime? now,
  }) async {
    final projects = await _projects(workspaceSlug);
    if (projects.isEmpty) return WorkspaceAnalytics.empty;

    final dio = await _client();
    var remaining = _requestBudget;
    final scans = <ProjectScan>[];

    for (final project in projects) {
      if (remaining <= 1) {
        // Out of budget. The project's server total arrives with its first
        // page, so skipping it means not knowing its size either — hence the
        // failed flag rather than a zero that would read as "empty project".
        scans.add(_unreadable(project));
        continue;
      }
      try {
        final result = await scanProject(
          workspaceSlug,
          project,
          client: dio,
          requestBudget: remaining,
        );
        remaining -= result.requests;
        scans.add(result.scan);
      } catch (_) {
        remaining -= 1;
        scans.add(_unreadable(project));
      }
    }

    return WorkspaceAnalytics.aggregate(scans, now: now);
  }

  static ProjectScan _unreadable(Project project) => ProjectScan(
        projectId: project.id,
        projectName: project.name,
        serverTotal: 0,
        items: const [],
        failed: true,
      );
}
