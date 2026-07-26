import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/screens/analytics/analytics_screen.dart';
import 'package:plane_mobile/services/analytics_service.dart';

/// The screen's whole reason to exist after this rewrite is that it says where
/// its numbers came from. These tests hold it to that: a figure the device
/// counted must not be presented as though the server had.
class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic> routes;
  _Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = routes[options.path];
    if (body == null) {
      return ResponseBody.fromString('{}', 404, headers: _headers);
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _headers);
  }

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Project _project(String id, String name) => Project(
      id: id,
      name: name,
      identifier: 'X',
      network: 2,
      totalMembers: 1,
      isMember: true,
      createdAt: DateTime(2025, 1, 1),
    );

void _serve(
    {required int totalCount, required List<Map<String, dynamic>> rows}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api/v1'));
  dio.httpClientAdapter = _Adapter({
    '/workspaces/acme/projects/p1/states/': [
      {'id': 's1', 'group': 'started'},
      {'id': 's2', 'group': 'completed'},
    ],
    '/workspaces/acme/projects/p1/issues/': {
      'total_count': totalCount,
      'count': rows.length,
      'next_cursor': '',
      'next_page_results': false,
      'results': rows,
    },
  });
  AnalyticsService.debugClient = dio;
  AnalyticsService.debugProjectLoader = (_) async => [_project('p1', 'Alpha')];
}

Widget _app() => const ProviderScope(
      child: MaterialApp(home: AnalyticsScreen(workspaceSlug: 'acme')),
    );

void main() {
  tearDown(() {
    AnalyticsService.debugClient = null;
    AnalyticsService.debugProjectLoader = null;
  });

  testWidgets('labels each overview figure with where it came from',
      (tester) async {
    _serve(totalCount: 2, rows: [
      {'id': 'i1', 'state': 's1', 'priority': 'urgent'},
      {'id': 'i2', 'state': 's2', 'priority': 'low'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Total work items'), findsOneWidget);
    expect(find.text('from server'), findsOneWidget);
    expect(find.text('counted here'), findsNWidgets(3));
  });

  testWidgets('a complete sweep says so and does not warn', (tester) async {
    _serve(totalCount: 2, rows: [
      {'id': 'i1', 'state': 's1', 'priority': 'urgent'},
      {'id': 'i2', 'state': 's2', 'priority': 'low'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('from all 2 work items'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
  });

  testWidgets('a partial sweep shows the coverage instead of hiding it',
      (tester) async {
    // The server says 900; one page came back with two rows and no next page,
    // which is what a truncated or partly failed sweep looks like.
    _serve(totalCount: 900, rows: [
      {'id': 'i1', 'state': 's1', 'priority': 'urgent'},
      {'id': 'i2', 'state': 's2', 'priority': 'low'},
    ]);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('2 of 900 work items'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    // The total card still shows the server's figure, not the scanned one.
    expect(find.text('900'), findsOneWidget);
  });

  testWidgets('an empty workspace gets the empty state, not zeroed charts',
      (tester) async {
    AnalyticsService.debugProjectLoader = (_) async => [];

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('No work items yet'), findsOneWidget);
  });
}
