import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/services/analytics_service.dart';

/// Answers requests from a routing table instead of a network.
///
/// Written by hand rather than pulled in as a mock package: the service's whole
/// contract with the API is "which path, which query params, what comes back",
/// and an adapter is the layer where all three are visible.
class _FakeAdapter implements HttpClientAdapter {
  /// path -> handler(query params) -> decoded JSON body.
  final Map<String, dynamic Function(Map<String, dynamic> query)> routes;

  /// Every request the service made, in order, for asserting on paging.
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
    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: _jsonHeaders);
  }

  static const _jsonHeaders = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Project _project(String id, String name) => Project(
      id: id,
      name: name,
      identifier: name.substring(0, 1).toUpperCase(),
      network: 2,
      totalMembers: 1,
      isMember: true,
      createdAt: DateTime(2025, 1, 1),
    );

/// One page of Plane's cursor-paginated work-item list.
Map<String, dynamic> _page({
  required List<Map<String, dynamic>> results,
  required int totalCount,
  String? nextCursor,
}) =>
    {
      'total_count': totalCount,
      'count': results.length,
      'next_cursor': nextCursor ?? '',
      'next_page_results': nextCursor != null,
      'results': results,
    };

void main() {
  tearDown(() {
    AnalyticsService.debugClient = null;
    AnalyticsService.debugProjectLoader = null;
  });

  group('getStateGroups', () {
    test('maps state ids to their group', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [
              {'id': 's1', 'group': 'started'},
              {'id': 's2', 'group': 'completed'},
            ],
      });

      final groups = await AnalyticsService.getStateGroups('acme', 'p1',
          client: _dioWith(adapter));

      expect(groups, {'s1': 'started', 's2': 'completed'});
    });

    test('handles a paginated states payload', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => {
              'results': [
                {'id': 's1', 'group': 'backlog'},
              ],
            },
      });

      final groups = await AnalyticsService.getStateGroups('acme', 'p1',
          client: _dioWith(adapter));

      expect(groups, {'s1': 'backlog'});
    });
  });

  group('scanProject', () {
    test('follows the cursor until the server says there is no more', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [
              {'id': 's1', 'group': 'started'},
              {'id': 's2', 'group': 'completed'},
            ],
        '/workspaces/acme/projects/p1/issues/': (query) {
          if (query['cursor'] == null) {
            return _page(
              totalCount: 3,
              nextCursor: '1000:1:0',
              results: [
                {'id': 'i1', 'state': 's1', 'priority': 'urgent'},
                {'id': 'i2', 'state': 's2', 'priority': 'low'},
              ],
            );
          }
          return _page(
            totalCount: 3,
            results: [
              {'id': 'i3', 'state': 's1', 'priority': 'urgent'},
            ],
          );
        },
      });

      final result = await AnalyticsService.scanProject(
        'acme',
        _project('p1', 'Alpha'),
        client: _dioWith(adapter),
      );

      expect(result.scan.items.length, 3);
      expect(result.scan.serverTotal, 3);
      expect(result.scan.isComplete, isTrue);
      // States once, then one request per page.
      expect(result.requests, 3);
    });

    test('asks only for the columns the aggregation reads', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [],
        '/workspaces/acme/projects/p1/issues/': (_) =>
            _page(totalCount: 0, results: []),
      });

      await AnalyticsService.scanProject('acme', _project('p1', 'Alpha'),
          client: _dioWith(adapter));

      final issueCall = adapter.calls
          .firstWhere((c) => c.path.endsWith('/issues/'))
          .queryParameters;
      expect(issueCall['fields'], 'id,state,priority,target_date');
      expect(issueCall['per_page'], 1000);
    });

    test('stops at the request budget and reports the scan as incomplete',
        () async {
      // A server that always claims another page: without the budget this loops
      // until the rate limiter or the battery gives out.
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [
              {'id': 's1', 'group': 'started'},
            ],
        '/workspaces/acme/projects/p1/issues/': (query) => _page(
              totalCount: 10000,
              nextCursor: '1000:${adapterCursorSeed++}:0',
              results: [
                {'id': 'i', 'state': 's1', 'priority': 'none'},
              ],
            ),
      });

      final result = await AnalyticsService.scanProject(
        'acme',
        _project('p1', 'Alpha'),
        client: _dioWith(adapter),
        requestBudget: 4,
      );

      expect(result.requests, 4);
      expect(result.scan.items.length, 3);
      expect(result.scan.serverTotal, 10000);
      expect(result.scan.isComplete, isFalse);
    });

    test('stops when the cursor repeats rather than looping forever', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [],
        '/workspaces/acme/projects/p1/issues/': (_) => _page(
              totalCount: 1,
              nextCursor: 'same',
              results: [
                {'id': 'i1', 'priority': 'none'},
              ],
            ),
      });

      final result = await AnalyticsService.scanProject(
        'acme',
        _project('p1', 'Alpha'),
        client: _dioWith(adapter),
        requestBudget: 20,
      );

      // First page, then one more that comes back with the same cursor.
      expect(result.requests, 3);
      expect(result.scan.items.length, 2);
    });
  });

  group('getWorkspaceAnalytics', () {
    test('aggregates across every project the loader returns', () async {
      final adapter = _FakeAdapter({
        '/workspaces/acme/projects/p1/states/': (_) => [
              {'id': 's1', 'group': 'started'},
            ],
        '/workspaces/acme/projects/p1/issues/': (_) => _page(
              totalCount: 2,
              results: [
                {
                  'id': 'i1',
                  'state': 's1',
                  'priority': 'urgent',
                  'target_date': '2025-01-01',
                },
                {'id': 'i2', 'state': 's1', 'priority': 'low'},
              ],
            ),
        '/workspaces/acme/projects/p2/states/': (_) => [
              {'id': 's9', 'group': 'completed'},
            ],
        '/workspaces/acme/projects/p2/issues/': (_) => _page(
              totalCount: 1,
              results: [
                {'id': 'i3', 'state': 's9', 'priority': 'urgent'},
              ],
            ),
      });

      AnalyticsService.debugClient = _dioWith(adapter);
      AnalyticsService.debugProjectLoader = (_) async => [
            _project('p1', 'Alpha'),
            _project('p2', 'Beta'),
          ];

      final data = await AnalyticsService.getWorkspaceAnalytics(
        'acme',
        now: DateTime(2025, 6, 1),
      );

      expect(data.total, 3);
      expect(data.scanned, 3);
      expect(data.isComplete, isTrue);
      expect(data.byStateGroup, {'started': 2, 'completed': 1});
      expect(data.byPriority, {'urgent': 2, 'low': 1});
      expect(data.overdue, 1);
      expect(data.completed, 1);
      expect(data.pending, 2);
      expect(data.projects.map((p) => p.projectName), ['Alpha', 'Beta']);
    });

    test('a project that fails does not take the screen down with it',
        () async {
      final adapter = _FakeAdapter({
        // p1 has no route at all, so its states call 404s.
        '/workspaces/acme/projects/p2/states/': (_) => [
              {'id': 's9', 'group': 'backlog'},
            ],
        '/workspaces/acme/projects/p2/issues/': (_) => _page(
              totalCount: 1,
              results: [
                {'id': 'i3', 'state': 's9', 'priority': 'none'},
              ],
            ),
      });

      AnalyticsService.debugClient = _dioWith(adapter);
      AnalyticsService.debugProjectLoader = (_) async => [
            _project('p1', 'Broken'),
            _project('p2', 'Beta'),
          ];

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.scanned, 1);
      expect(data.byStateGroup, {'backlog': 1});
      expect(data.projects.length, 2);
      // …but it is not passed off as a complete picture.
      expect(data.isComplete, isFalse);
      expect(data.incompleteProjects, 1);
    });

    test('no projects means an empty result and no requests', () async {
      final adapter = _FakeAdapter({});
      AnalyticsService.debugClient = _dioWith(adapter);
      AnalyticsService.debugProjectLoader = (_) async => [];

      final data = await AnalyticsService.getWorkspaceAnalytics('acme');

      expect(data.isEmpty, isTrue);
      expect(adapter.calls, isEmpty);
    });
  });
}

/// Makes each synthetic page hand back a different cursor, so the service's
/// repeat-cursor guard does not fire before the budget test can run.
int adapterCursorSeed = 1;
