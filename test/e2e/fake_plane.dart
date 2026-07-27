import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/api_client.dart';
import 'package:plane_mobile/database/app_database.dart';

/// A Plane instance, in memory.
///
/// The service tests answer one service from a routing table. This answers the
/// *app* — every service it reaches on the way through a screen — so a test
/// can boot the real widget tree and tap through it.
///
/// That is the class of defect the unit tests cannot reach and manual checking
/// twice missed: a screen that renders nothing because a call three layers
/// down 404s, or that has no route to it at all. Both of those show up here as
/// a widget that is not on screen.
///
/// Routes are matched by the **last** matching pattern registered, so a test
/// can override one of the defaults without rebuilding the set.
class FakePlane implements HttpClientAdapter {
  FakePlane() {
    _installDefaults();
  }

  /// Every request the app made, in order. Assert against this when what
  /// matters is that a call was or was not made.
  final List<RequestOptions> calls = [];

  final List<_Route> _routes = [];

  /// Register a handler. [pattern] is matched against the path with
  /// `contains`, which is enough here and keeps the tests readable.
  void on(
    String method,
    String pattern,
    Object? Function(RequestOptions request) handler,
  ) {
    _routes.add(_Route(method.toUpperCase(), pattern, handler));
  }

  /// Answer [pattern] with [body], whatever the request.
  void reply(String method, String pattern, Object? body) =>
      on(method, pattern, (_) => body);

  /// Answer [pattern] with a status code instead of a body.
  void fail(String method, String pattern, int status) =>
      on(method, pattern, (_) => _Status(status));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final method = options.method.toUpperCase();
    final path = options.path;

    for (final route in _routes.reversed) {
      if (route.method != method) continue;
      if (!path.contains(route.pattern)) continue;
      final body = route.handler(options);
      if (body is _Status) {
        return ResponseBody.fromString(
          jsonEncode({'error': 'denied'}),
          body.code,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: _jsonHeaders,
      );
    }

    // An unrouted call is a fact worth failing on rather than a silent empty
    // list: a screen that draws nothing because of one is exactly what these
    // tests exist to catch, and a 404 here makes the cause obvious.
    return ResponseBody.fromString(
      jsonEncode({'error': 'no route for $method $path'}),
      404,
      headers: _jsonHeaders,
    );
  }

  @override
  void close({bool force = false}) {}

  static const _jsonHeaders = {
    Headers.contentTypeHeader: ['application/json'],
  };

  /// Whether any request was made to a path containing [pattern].
  bool called(String pattern) => calls.any((c) => c.path.contains(pattern));

  // --- The instance's contents ---------------------------------------------

  static const String slug = 'acme';
  static const String userId = 'user-1';
  static const String projectId = 'project-1';
  static const String issueId = 'issue-1';

  static Map<String, dynamic> get user => {
        'id': userId,
        'email': 'ada@example.org',
        'display_name': 'Ada',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
      };

  static Map<String, dynamic> get project => {
        'id': projectId,
        'name': 'Aurora',
        'identifier': 'AUR',
        'description': 'The demo project',
        'network': 2,
        'total_members': 1,
        'total_issues': 2,
        'is_member': true,
        'created_at': '2026-01-01T10:00:00Z',
        'cycle_view': true,
        'module_view': true,
        'issue_views_view': true,
        'page_view': true,
        'intake_view': false,
      };

  static List<Map<String, dynamic>> get states => [
        {
          'id': 'state-todo',
          'name': 'Todo',
          'color': '#3b82f6',
          'group': 'unstarted',
          'sequence': 1,
        },
        {
          'id': 'state-done',
          'name': 'Done',
          'color': '#10b981',
          'group': 'completed',
          'sequence': 2,
        },
      ];

  static Map<String, dynamic> issue({
    String id = issueId,
    String name = 'Fix the header',
    String state = 'state-todo',
    int sequenceId = 7,
    String priority = 'high',
  }) =>
      {
        'id': id,
        'name': name,
        'description_html': '<p>The header does not size to its text.</p>',
        'state_id': state,
        'priority': priority,
        'sequence_id': sequenceId,
        'project_id': projectId,
        'assignee_ids': <String>[],
        'label_ids': <String>[],
        'module_ids': <String>[],
        'sub_issues_count': 0,
        'created_at': '2026-01-02T10:00:00Z',
        'updated_at': '2026-01-02T10:00:00Z',
      };

  /// Everything a boot of the app touches, answered.
  void _installDefaults() {
    reply('GET', '/users/me/workspaces/', [
      {
        'id': 'ws-1',
        'name': 'Acme',
        'slug': slug,
        'total_members': 1,
        'created_at': '2026-01-01T10:00:00Z',
      }
    ]);
    reply('GET', '/users/me/', user);
    reply('GET', '/workspaces/$slug/projects/', [project]);
    reply('GET', '/workspaces/$slug/members/', [
      {'id': 'wm-1', 'member': user, 'role': 20}
    ]);
    reply('GET', '/workspace-members/me/', {'role': 20, 'member': user});
    reply('GET', '/project-members/me/', {'role': 20, 'member': user});

    final scope = '/workspaces/$slug/projects/$projectId';
    reply('GET', '$scope/states/', states);
    reply('GET', '$scope/labels/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/members/', [
      {'id': 'pm-1', 'member': user, 'role': 20}
    ]);
    reply('GET', '$scope/cycles/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/modules/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/pages/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/views/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/archived-issues/', {'results': <Object>[]});
    reply('GET', '$scope/project-estimates/', <Map<String, dynamic>>[]);
    reply('GET', '$scope/issues/', {
      'results': [
        issue(),
        issue(id: 'issue-2', name: 'Ship it', sequenceId: 8)
      ],
      'total_count': 2,
    });
    reply('GET', '$scope/issues/$issueId/', issue());

    reply('GET', '/workspaces/$slug/draft-issues/', {'results': <Object>[]});
    reply('GET', '/workspaces/$slug/user-favorites/', <Object>[]);
    reply('GET', '/workspaces/$slug/users/notifications/', <Object>[]);
    reply('GET', '/workspaces/$slug/user-activity/$userId/',
        {'results': <Object>[]});
  }
}

/// Boots SQLite and the secure storage the app expects to find already
/// configured, and points every client at [fake].
///
/// Call from `setUp`. The teardown is registered here so no test has to
/// remember it.
Future<FakePlane> useFakePlane() async {
  final fake = FakePlane();

  // The keys SecureStorage actually writes, prefix and all. Getting these
  // wrong reads back null, and Dio then throws on an empty base URL rather
  // than making a request the fake could answer.
  FlutterSecureStorage.setMockInitialValues({
    'plane_base_url': 'https://plane.test',
    'plane_api_key': 'token',
    'plane_workspace_slug': FakePlane.slug,
  });

  _installInMemoryDatabase();

  ApiClient.reset();
  ApiClient.debugAdapter = fake;
  addTearDown(() {
    ApiClient.debugAdapter = null;
    ApiClient.reset();
  });

  return fake;
}

/// One-time process setup.
///
/// Deliberately **without** SQLite. The app reads its local cache before the
/// network, and pointing that at a real database through FFI makes it do real
/// file I/O — which never completes inside `testWidgets`, because the fake
/// clock cannot pump a completion that is not a timer. The screen then waits
/// on a future that will not resolve and makes no request at all.
///
/// With no database registered the cache read throws immediately, the app
/// falls through to the network, and the screen loads. That is also the more
/// useful path to test: it is what a cold install does.
void initFakePlaneBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// An empty database, in memory and in this isolate.
///
/// Three ways to give the app a database in a widget test, and only this one
/// works. The **default FFI factory** runs in an isolate, so its futures
/// complete off the test's clock and never resolve inside `testWidgets` — the
/// screen then waits forever on its cache read and never reaches the network.
/// **No database at all** makes the reads fail fast, which would be fine, but
/// the writes then throw out of an unguarded path and fail the test. The
/// no-isolate factory runs in process, so every await resolves when the test
/// pumps.
///
/// In memory, so no test sees another's rows and every screen takes the
/// cold-install path: read nothing locally, fetch, draw what arrived.
void _installInMemoryDatabase() {
  sqfliteFfiInit();
  // `databaseFactoryFfiNoIsolate`, not the default: the isolate-backed factory
  // does its work off the test's clock and its futures never complete inside
  // `testWidgets`, so a screen waits forever on its cache read and never
  // reaches the network. This one runs in-process.
  databaseFactory = databaseFactoryFfiNoIsolate;

  // In memory, so no test can see another's rows and nothing survives the run.
  AppDatabase.debugPath = inMemoryDatabasePath;
  addTearDown(() async {
    // Close the handle as well as clearing the override: the open database is
    // cached on the class, so the next test would otherwise reuse this one's.
    await AppDatabase.deleteDatabase();
    AppDatabase.debugPath = null;
  });
}

/// Pump until the screen has had time to load, without requiring the tree to
/// go still.
///
/// `pumpAndSettle` cannot be used on several of these screens: the M3
/// Expressive loading indicator animates continuously, so a screen that is
/// still loading — or one that keeps a decorative animation after it has
/// loaded — never settles and the call times out. Pumping a fixed number of
/// frames past the futures is what a real user's first second looks like
/// anyway.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class _Route {
  final String method;
  final String pattern;
  final Object? Function(RequestOptions request) handler;

  _Route(this.method, this.pattern, this.handler);
}

class _Status {
  final int code;
  const _Status(this.code);
}
