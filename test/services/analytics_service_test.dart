import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/analytics_service.dart';

/// Answers requests from a routing table instead of a network.
///
/// Written by hand rather than pulled in as a mock package: the service's whole
/// contract with the API is "which path, which query params, what comes back",
/// and an adapter is the layer where all three are visible.
///
/// Routes are keyed by path *and* discriminated by query, because two of the
/// five reads share one path and differ only in `x_axis`.
class _FakeAdapter implements HttpClientAdapter {
  /// path -> handler(query params) -> a body, or a status code to fail with.
  final Map<String, dynamic Function(Map<String, dynamic> query)> routes;

  /// Every request the service made, in order.
  final List<RequestOptions> calls = [];

  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final handler = routes[options.path];
    if (handler == null) {
      return ResponseBody.fromString('{"error":"no route"}', 404,
          headers: _jsonHeaders);
    }
    final body = handler(options.queryParameters);
    if (body is int) {
      return ResponseBody.fromString('{"error":"denied"}', body,
          headers: _jsonHeaders);
    }
    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: _jsonHeaders);
  }

  static const _jsonHeaders = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

/// `advance-analytics/?tab=work-items`.
Map<String, dynamic> overview({
  int total = 10,
  int backlog = 2,
  int unstarted = 1,
  int started = 3,
  int completed = 4,
}) =>
    {
      'total_work_items': {'count': total},
      'backlog_work_items': {'count': backlog},
      'un_started_work_items': {'count': unstarted},
      'started_work_items': {'count': started},
      'completed_work_items': {'count': completed},
    };

/// `advance-analytics-charts/?type=custom-work-items`.
Map<String, dynamic> chart(Map<String, int> counts) => {
      'data': [
        for (final e in counts.entries)
          {'key': e.key, 'name': e.key, 'count': e.value},
      ],
      'schema': <String, dynamic>{},
    };

/// One row of `advance-analytics-stats/?type=work-items`.
Map<String, dynamic> projectRow(String id, String name, {int started = 1}) => {
      'project_id': id,
      'project__name': name,
      'backlog_work_items': 0,
      'un_started_work_items': 0,
      'started_work_items': started,
      'completed_work_items': 0,
      'cancelled_work_items': 0,
    };

/// The full happy-path routing table, with individual routes overridable.
_FakeAdapter _server({
  dynamic Function(Map<String, dynamic>)? advanceAnalytics,
  dynamic Function(Map<String, dynamic>)? charts,
  dynamic Function(Map<String, dynamic>)? stats,
  dynamic Function(Map<String, dynamic>)? defaultAnalytics,
}) =>
    _FakeAdapter({
      '/workspaces/acme/advance-analytics/':
          advanceAnalytics ?? (_) => overview(),
      '/workspaces/acme/advance-analytics-charts/': charts ??
          (query) => query['x_axis'] == 'PRIORITY'
              ? chart({'urgent': 6, 'low': 4})
              : chart({'started': 6, 'completed': 4}),
      '/workspaces/acme/advance-analytics-stats/': stats ??
          (_) => [
                projectRow('p1', 'Alpha', started: 4),
                projectRow('p2', 'Beta', started: 2),
              ],
      '/workspaces/acme/default-analytics/':
          defaultAnalytics ?? (_) => {'total_issues': 10, 'open_issues': 3},
    });

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  tearDown(() {
    AnalyticsService.debugClient = null;
  });

  group('getWorkspaceAnalytics', () {
    test('reads every figure from the analytics API', () async {
      final adapter = _server();
      AnalyticsService.debugClient = _dioWith(adapter);

      final data = await AnalyticsService.getWorkspaceAnalytics(
        'acme',
        now: DateTime(2025, 6, 10, 12),
      );

      expect(data.total, 10);
      expect(data.completed, 4);
      // backlog + un_started + started.
      expect(data.pending, 6);
      expect(data.overdue, 3);
      expect(data.byPriority, {'urgent': 6, 'low': 4});
      expect(data.byStateGroup, {'started': 6, 'completed': 4});
      expect(data.projects!.map((p) => p.projectName), ['Alpha', 'Beta']);
      expect(data.isComplete, isTrue);
    });

    test('does not page anything', () async {
      // The whole point of the rewrite: five requests, none of them a
      // work-item list, no cursor, no per_page.
      final adapter = _server();
      AnalyticsService.debugClient = _dioWith(adapter);

      await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(adapter.calls.length, 5);
      expect(adapter.calls.any((c) => c.path.endsWith('/issues/')), isFalse);
      expect(
        adapter.calls.any((c) => c.queryParameters.containsKey('cursor')),
        isFalse,
      );
    });

    test('asks each endpoint for the shape it needs', () async {
      final adapter = _server();
      AnalyticsService.debugClient = _dioWith(adapter);

      await AnalyticsService.getWorkspaceAnalytics('acme');

      Map<String, dynamic> query(String path, [String? xAxis]) => adapter.calls
          .firstWhere((c) =>
              c.path == path &&
              (xAxis == null || c.queryParameters['x_axis'] == xAxis))
          .queryParameters;

      expect(query('/workspaces/acme/advance-analytics/')['tab'], 'work-items');
      expect(query('/workspaces/acme/advance-analytics-stats/')['type'],
          'work-items');
      for (final axis in ['STATE_GROUPS', 'PRIORITY']) {
        final q = query('/workspaces/acme/advance-analytics-charts/', axis);
        expect(q['type'], 'custom-work-items');
        expect(q['x_axis'], axis);
      }
    });

    test('scopes the overdue count to the projects the stats call reported',
        () async {
      final adapter = _server();
      AnalyticsService.debugClient = _dioWith(adapter);

      await AnalyticsService.getWorkspaceAnalytics(
        'acme',
        now: DateTime(2025, 6, 10, 12),
      );

      final query = adapter.calls
          .firstWhere((c) => c.path.endsWith('/default-analytics/'))
          .queryParameters;

      // default-analytics counts the whole workspace unless told otherwise,
      // while the advance-analytics family is already limited to the caller's
      // projects. Without this the overdue card would be on a wider scope than
      // every other figure on the screen.
      expect(query['project'], 'p1,p2');
      // ";before" is issue_filters' way of writing <=, and a zero-padded date
      // is what the DateField comparison expects.
      expect(query['target_date'], '2025-06-10;before');
    });

    test('zero-pads the overdue date', () async {
      // Django compares a DateField against the string as given, so an
      // unpadded "2025-1-5" is not a date it will parse.
      final adapter = _server();
      AnalyticsService.debugClient = _dioWith(adapter);

      await AnalyticsService.getWorkspaceAnalytics(
        'acme',
        now: DateTime(2025, 1, 5, 23, 59),
      );

      expect(
        adapter.calls
            .firstWhere((c) => c.path.endsWith('/default-analytics/'))
            .queryParameters['target_date'],
        '2025-01-05;before',
      );
    });

    test('an empty workspace needs no overdue request', () async {
      final adapter = _server(
        advanceAnalytics: (_) => overview(
            total: 0, backlog: 0, unstarted: 0, started: 0, completed: 0),
        charts: (_) => chart({}),
        stats: (_) => [],
      );
      AnalyticsService.debugClient = _dioWith(adapter);

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.isEmpty, isTrue);
      expect(data.overdue, 0);
      expect(
        adapter.calls.any((c) => c.path.endsWith('/default-analytics/')),
        isFalse,
      );
    });

    test('one failed panel does not take the others down', () async {
      final adapter = _server(
        charts: (query) =>
            query['x_axis'] == 'PRIORITY' ? 403 : chart({'started': 6}),
      );
      AnalyticsService.debugClient = _dioWith(adapter);

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.byPriority, isNull);
      expect(data.byStateGroup, {'started': 6});
      expect(data.total, 10);
      expect(data.isComplete, isFalse);
      expect(data.unavailable, ['the priority breakdown']);
    });

    test('a failed project read leaves the overdue count unstated', () async {
      // The overdue query has to name the projects to stay on the same scope
      // as the rest of the screen. Without that list the honest answer is no
      // answer, not an unscoped count that would silently mean something else.
      final adapter = _server(stats: (_) => 403);
      AnalyticsService.debugClient = _dioWith(adapter);

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.projects, isNull);
      expect(data.overdue, isNull);
      expect(
        adapter.calls.any((c) => c.path.endsWith('/default-analytics/')),
        isFalse,
      );
      expect(
          data.unavailable, ['the overdue count', 'the per-project breakdown']);
    });

    test('everything failing is reported as nothing, not as an empty workspace',
        () async {
      AnalyticsService.debugClient = _dioWith(_FakeAdapter({}));

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.hasAnyFigure, isFalse);
      expect(data.isEmpty, isFalse);
    });
  });
}
