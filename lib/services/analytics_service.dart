import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/analytics.dart';

/// Reads the analytics screen's figures from Plane's analytics API.
///
/// ## What replaced what
///
/// This used to sweep every project's work-item list to its last page and count
/// on the device — up to 45 requests, visited serially so as not to burst the
/// API token's 60-per-minute throttle, with a request budget and a coverage
/// figure to admit when it ran out. All of that existed for one reason: the
/// analytics endpoints were unreachable. They live on the internal API behind a
/// session cookie, and the app's token only reached `/api/v1/`, which has no
/// analytics module.
///
/// The session proxy in `plane-mobile-api` made them reachable. Five requests
/// now replace the sweep, each one an aggregate the database computed:
///
/// | Figure | Endpoint | Query |
/// |---|---|---|
/// | total / completed / pending | `advance-analytics/` | `tab=work-items` |
/// | by state group | `advance-analytics-charts/` | `type=custom-work-items&x_axis=STATE_GROUPS` |
/// | by priority | `advance-analytics-charts/` | `type=custom-work-items&x_axis=PRIORITY` |
/// | per project | `advance-analytics-stats/` | `type=work-items` |
/// | overdue | `default-analytics/` | `project=…&target_date=…;before` |
///
/// The first four are independent and go out together. The overdue call waits
/// on the fourth, because it needs the project list to scope itself the same
/// way — see [_overdue].
///
/// With no paging there is no budget to run out of and no partial scan to
/// report. What can still go wrong is a request failing, and that is reported
/// per panel: see the note on null in `models/analytics.dart`.
class AnalyticsService {
  /// Injected by tests in place of a real HTTP client.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  static Future<WorkspaceAnalytics> getWorkspaceAnalytics(
    String workspaceSlug, {
    DateTime? now,
  }) async {
    final dio = await _client();
    final base = '/workspaces/$workspaceSlug';

    final responses = await Future.wait([
      _get(dio, '$base/advance-analytics/', {'tab': 'work-items'}),
      _get(dio, '$base/advance-analytics-charts/', {
        'type': 'custom-work-items',
        'x_axis': 'STATE_GROUPS',
      }),
      _get(dio, '$base/advance-analytics-charts/', {
        'type': 'custom-work-items',
        'x_axis': 'PRIORITY',
      }),
      _get(dio, '$base/advance-analytics-stats/', {'type': 'work-items'}),
    ]);

    final overview = responses[0];
    final counts = overview is Map
        ? WorkItemCounts.fromJson(Map<String, dynamic>.from(overview))
        : null;
    final byStateGroup =
        responses[1] == null ? null : analyticsChartCounts(responses[1]);
    final byPriority =
        responses[2] == null ? null : analyticsChartCounts(responses[2]);
    final projects = responses[3] == null
        ? null
        : ProjectAnalytics.listFromJson(responses[3]);

    final overdue = await _overdue(
      dio,
      workspaceSlug,
      projects,
      now ?? DateTime.now(),
    );

    return WorkspaceAnalytics(
      total: counts?.total,
      completed: counts?.completed,
      pending: counts?.pending,
      overdue: overdue,
      byStateGroup: byStateGroup,
      byPriority: byPriority,
      projects: projects,
    );
  }

  /// Open work whose target date has passed.
  ///
  /// The only figure on the screen the `advance-analytics*` family cannot
  /// produce: those three views build their querysets from a fixed set of
  /// filters and never call `issue_filters`, so there is no way to ask them for
  /// a date-bounded subset. `default-analytics/` does call it, and its
  /// `open_issues` is already restricted to the backlog / unstarted / started
  /// groups, so one request with a target-date filter answers the question
  /// outright.
  ///
  /// `target_date=<today>;before` is the filter grammar's `<=`: `date_filter`
  /// in `plane/utils/issue_filters.py` reads any term that is not `after` as an
  /// upper bound. A target date of today therefore counts as passed, which is
  /// the rule `Issue.isOverdue` applies everywhere else in the app.
  ///
  /// The `project=` list exists because `default-analytics/` counts the whole
  /// workspace rather than the caller's projects, unlike the other three, and
  /// two different scopes on one screen would be worse than no figure at all.
  /// The list comes from `advance-analytics-stats/`, which returns every
  /// project holding at least one work item — which is every project that could
  /// hold an overdue one.
  ///
  /// So a failed project read means no overdue figure either: without the list
  /// the count could not be scoped, and an unscoped one would quietly be
  /// answering a different question.
  static Future<int?> _overdue(
    Dio dio,
    String workspaceSlug,
    List<ProjectAnalytics>? projects,
    DateTime asOf,
  ) async {
    if (projects == null) return null;
    if (projects.isEmpty) return 0;

    final today = '${asOf.year.toString().padLeft(4, '0')}-'
        '${asOf.month.toString().padLeft(2, '0')}-'
        '${asOf.day.toString().padLeft(2, '0')}';

    final body =
        await _get(dio, '/workspaces/$workspaceSlug/default-analytics/', {
      'project': projects.map((p) => p.projectId).join(','),
      'target_date': '$today;before',
    });

    if (body is! Map) return null;
    return (body['open_issues'] as num?)?.toInt();
  }

  /// One analytics read, yielding null instead of throwing.
  ///
  /// A failure here is not exceptional. The `advance-analytics*` views admit
  /// admins and members only, while `default-analytics/` also admits guests, so
  /// a guest gets a 403 on four of the five and a perfectly good overdue-free
  /// screen — provided one dead panel does not take the other four with it.
  /// The caller turns null into "unavailable" on that panel and says so.
  static Future<dynamic> _get(
    Dio dio,
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final response = await dio.get(path, queryParameters: query);
      return response.data;
    } catch (_) {
      return null;
    }
  }
}
