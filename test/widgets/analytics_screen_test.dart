import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/screens/analytics/analytics_screen.dart';
import 'package:plane_mobile/services/analytics_service.dart';

/// The screen's reason to exist beyond the charts is that it says where its
/// numbers came from. These tests hold it to that: a panel the server never
/// answered for must not be drawn as a zero.
class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic Function(Map<String, dynamic> query)> routes;
  _Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = routes[options.path];
    if (handler == null) {
      return ResponseBody.fromString('{}', 404, headers: _headers);
    }
    final body = handler(options.queryParameters);
    if (body is int) {
      return ResponseBody.fromString('{}', body, headers: _headers);
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _headers);
  }

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _chart(Map<String, int> counts) => {
      'data': [
        for (final e in counts.entries) {'key': e.key, 'count': e.value},
      ],
      'schema': <String, dynamic>{},
    };

void _serve({
  dynamic Function(Map<String, dynamic>)? charts,
  dynamic Function(Map<String, dynamic>)? stats,
  int total = 12,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
  dio.httpClientAdapter = _Adapter({
    '/workspaces/acme/advance-analytics/': (_) => {
          'total_work_items': {'count': total},
          'backlog_work_items': {'count': 3},
          'un_started_work_items': {'count': 1},
          'started_work_items': {'count': 4},
          'completed_work_items': {'count': 4},
        },
    '/workspaces/acme/advance-analytics-charts/': charts ??
        (query) => query['x_axis'] == 'PRIORITY'
            ? _chart({'urgent': 8, 'low': 4})
            : _chart({'started': 8, 'completed': 4}),
    '/workspaces/acme/advance-analytics-stats/': stats ??
        (_) => [
              {
                'project_id': 'p1',
                'project__name': 'Alpha',
                'backlog_work_items': 3,
                'un_started_work_items': 1,
                'started_work_items': 4,
                'completed_work_items': 4,
                'cancelled_work_items': 0,
              },
            ],
    '/workspaces/acme/default-analytics/': (_) =>
        {'total_issues': total, 'open_issues': 2},
  });
  AnalyticsService.debugClient = dio;
}

Widget _app() => const ProviderScope(
      child: MaterialApp(home: AnalyticsScreen(workspaceSlug: 'acme')),
    );

void main() {
  tearDown(() {
    AnalyticsService.debugClient = null;
  });

  testWidgets('labels each overview figure with where it came from',
      (tester) async {
    _serve();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Total work items'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // All four are database counts now, and all four say so.
    expect(find.text('from server'), findsNWidgets(4));
    expect(find.text('counted here'), findsNothing);
  });

  testWidgets(
      'a complete answer says nothing was counted here and does not '
      'warn', (tester) async {
    _serve();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing on this screen is counted on the device'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
  });

  testWidgets('a panel the server did not answer for is named, not zeroed',
      (tester) async {
    _serve(
      charts: (query) =>
          query['x_axis'] == 'PRIORITY' ? 403 : _chart({'started': 8}),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('did not answer for the priority breakdown'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);

    // The overview cards fill the test viewport, so the charts below them are
    // not built until the list is dragged up.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unavailable'), findsOneWidget);
  });

  testWidgets('a state group this build does not know about still shows',
      (tester) async {
    // The chart orders by kStateGroups and would otherwise drop anything not
    // in it, which would silently hide a group a newer Plane invented.
    _serve(
      charts: (query) => query['x_axis'] == 'PRIORITY'
          ? _chart({'urgent': 8})
          : _chart({'started': 8, 'triaged': 4}),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Triaged'), findsOneWidget);
  });

  testWidgets('projects are listed largest first', (tester) async {
    _serve(
      stats: (_) => [
        {'project_id': 'p1', 'project__name': 'Small', 'started_work_items': 2},
        {'project_id': 'p2', 'project__name': 'Big', 'started_work_items': 9},
      ],
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final big = tester.getTopLeft(find.text('Big')).dy;
    final small = tester.getTopLeft(find.text('Small')).dy;
    expect(big, lessThan(small));
  });

  testWidgets('a missing figure shows a dash rather than a plausible zero',
      (tester) async {
    // Losing the project list also loses the overdue count, which cannot be
    // scoped without it.
    _serve(stats: (_) => 500);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('unavailable'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('an empty workspace gets the empty state, not zeroed charts',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
    dio.httpClientAdapter = _Adapter({
      '/workspaces/acme/advance-analytics/': (_) => {
            'total_work_items': {'count': 0},
          },
      '/workspaces/acme/advance-analytics-charts/': (_) => _chart({}),
      '/workspaces/acme/advance-analytics-stats/': (_) => [],
    });
    AnalyticsService.debugClient = dio;

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('No work items yet'), findsOneWidget);
  });

  testWidgets('nothing arriving is an error, not an empty workspace',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
    dio.httpClientAdapter = _Adapter({});
    AnalyticsService.debugClient = dio;

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Failed to load analytics'), findsOneWidget);
    expect(find.text('No work items yet'), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  //  The provenance, held to after the screen was moved onto the shared
  //  widgets.
  //
  //  Moving `_NoData` onto `EmptyStateWidget` is the change most likely to lose
  //  this quietly: the obvious next step is to move `_Unavailable` there too,
  //  and then a panel the server never answered for is drawn in the same words,
  //  the same colour and the same glyph as a panel that answered "none". Those
  //  are different facts and the whole screen exists to keep them apart.
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('an empty panel and a missing panel do not read the same',
      (tester) async {
    // Priority answered, with nothing in it. State never answered.
    _serve(
      charts: (query) => query['x_axis'] == 'PRIORITY' ? _chart({}) : 403,
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Only the state breakdown is named as missing; the empty priority chart
    // is not, because nothing went wrong with it.
    expect(
      find.textContaining('did not answer for the state breakdown'),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(
      find.text('Unavailable — the server did not answer for this'),
      findsOneWidget,
    );
    // The missing panel keeps the warning glyph the note at the top uses for
    // the same meaning; the empty one has no glyph at all. The note itself has
    // scrolled off by now, so this is the panel's own.
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });

  testWidgets('a project row still announces every count it draws',
      (tester) async {
    // The row is a PlaneRow now, and PlaneRow hands its label to M3EPressable,
    // which *replaces* the subtree's semantics — so anything the label does not
    // say is not said at all.
    final handle = tester.ensureSemantics();
    _serve();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Alpha, 12 work items, 4 completed, 3 Backlog, 1 Unstarted, '
        '4 Started, 4 Completed',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a missing project panel gets no count pill', (tester) async {
    // The shared SectionHeader draws a count in a pill. Passing a zero there
    // for a panel that never answered would restate, in the heading, exactly
    // the lie the cards below it refuse to tell.
    _serve(stats: (_) => 500);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('WORK ITEMS BY PROJECT'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(
      find.text('Unavailable — the server did not answer for this'),
      findsOneWidget,
    );
  });

  testWidgets('a panel that answered with no projects is an empty state',
      (tester) async {
    _serve(stats: (_) => []);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('No projects with work items'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsNothing);
    // The heading's pill is honest here: the server said zero.
    expect(find.textContaining('did not answer'), findsNothing);
  });
}
