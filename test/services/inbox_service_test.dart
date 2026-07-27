import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/database/app_database.dart';
import 'package:plane_mobile/models/inbox_entry.dart';
import 'package:plane_mobile/services/inbox_service.dart';
import 'package:plane_mobile/services/notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers requests from a routing table instead of a network.
///
/// The same hand-written seam [AnalyticsService]'s tests use: what matters
/// about this service is which paths it calls and how it merges two answers,
/// and an adapter is where both are visible.
class _FakeAdapter implements HttpClientAdapter {
  /// Path suffix -> body, or an int to fail with that status.
  final Map<String, dynamic> routes;
  final List<RequestOptions> calls = [];

  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final key = routes.keys.firstWhere(
      (k) => options.path.endsWith(k),
      orElse: () => '',
    );
    if (key.isEmpty) {
      return ResponseBody.fromString('{"error":"no route"}', 404,
          headers: _jsonHeaders);
    }
    final body = routes[key];
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

/// One row as `workspaces/{slug}/user-activity/{id}/` sends it.
Map<String, dynamic> activityRow({
  required String id,
  String issueName = 'Fix the header',
  String field = 'state',
  String verb = 'updated',
  String newValue = 'Done',
  String createdAt = '2026-01-02T10:00:00Z',
}) =>
    {
      'id': id,
      'field': field,
      'verb': verb,
      'new_value': newValue,
      'created_at': createdAt,
      'issue': 'issue-$id',
      'project': 'project-1',
      'actor_detail': {'display_name': 'Andrew'},
      'issue_detail': {
        'id': 'issue-$id',
        'name': issueName,
        'sequence_id': 12,
        'priority': 'high',
      },
      'project_detail': {'id': 'project-1', 'identifier': 'PLM'},
    };

/// One row as `workspaces/{slug}/users/notifications/` sends it.
Map<String, dynamic> notificationRow({
  required String id,
  String? activityId,
  String issueName = 'Ship the release',
  String createdAt = '2026-01-03T10:00:00Z',
  String? readAt,
}) =>
    {
      'id': id,
      'title': issueName,
      'entity_name': 'issue',
      'read_at': readAt,
      'archived_at': null,
      'created_at': createdAt,
      'data': {
        'issue': {
          'id': 'issue-n-$id',
          'name': issueName,
          'identifier': 'PLM',
          'sequence_id': 99,
          'priority': 'urgent',
          'state_group': 'started',
          'project': 'project-1',
        },
        'triggered_by_details': {'display_name': 'Sam'},
        if (activityId != null)
          'issue_activity': {
            'id': activityId,
            'field': 'comment',
            'verb': 'created',
            'new_value': '',
          },
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'base_url': 'https://plane.example',
      'api_key': 'token',
      'workspace_slug': 'acme',
    });
    await AppDatabase.clearAll();
  });

  tearDown(() {
    InboxService.debugClient = null;
    NotificationService.debugClient = null;
  });

  /// Point both services at one routing table.
  _FakeAdapter wire(Map<String, dynamic> routes) {
    final adapter = _FakeAdapter(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://plane.example'))
      ..httpClientAdapter = adapter;
    InboxService.debugClient = dio;
    NotificationService.debugClient = dio;
    return adapter;
  }

  Future<List<InboxEntry>> feed() => InboxService.feed(
        workspaceSlug: 'acme',
        userId: 'user-1',
      );

  group('InboxService.feed', () {
    test('merges both of Plane\'s feeds, newest first', () async {
      wire({
        '/users/notifications/': [
          notificationRow(id: 'n1', createdAt: '2026-01-03T10:00:00Z'),
        ],
        '/user-activity/user-1/': {
          'results': [
            activityRow(id: 'a1', createdAt: '2026-01-04T10:00:00Z'),
            activityRow(id: 'a2', createdAt: '2026-01-01T10:00:00Z'),
          ],
        },
      });

      final entries = await feed();

      expect(entries.map((e) => e.id), ['a1', 'n1', 'a2']);
      expect(entries.first.kind, InboxEntryKind.activity);
      expect(entries[1].kind, InboxEntryKind.notification);
    });

    test('reads the activity half from the workspace-scoped route', () async {
      final adapter = wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {'results': <Map<String, dynamic>>[]},
      });

      await feed();

      // Not `users/me/activities/`, which is not workspace-scoped, and not a
      // hand-written query on the shim. This route carries
      // WorkspaceEntityPermission and filters on the caller's project
      // membership, which is the whole point of the move.
      expect(
        adapter.calls.map((c) => c.path),
        contains(contains('/workspaces/acme/user-activity/user-1/')),
      );
    });

    test('drops the activity row a notification already covers', () async {
      wire({
        '/users/notifications/': [
          notificationRow(id: 'n1', activityId: 'a1'),
        ],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1'), activityRow(id: 'a2')],
        },
      });

      final entries = await feed();

      expect(entries.map((e) => e.id), ['n1', 'a2']);
    });

    test('an empty notification half still yields the activity half', () async {
      // The single-operator case that made this feed necessary: Plane never
      // notifies the actor of their own activity, so `notifications/` is
      // legitimately empty and the screen would otherwise be blank.
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entries = await feed();

      expect(entries, hasLength(1));
      expect(entries.single.kind, InboxEntryKind.activity);
    });

    test('a failing half leaves the other half on screen', () async {
      wire({
        '/users/notifications/': 500,
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      expect(await feed(), hasLength(1));
    });

    test('no user id means no activity request, not a broken feed', () async {
      final adapter = wire({
        '/users/notifications/': [notificationRow(id: 'n1')],
      });

      final entries =
          await InboxService.feed(workspaceSlug: 'acme', userId: '');

      expect(entries.map((e) => e.id), ['n1']);
      expect(
        adapter.calls.every((c) => !c.path.contains('user-activity')),
        isTrue,
      );
    });
  });

  group('activity read and dismissed marks', () {
    test('a read mark survives the next fetch', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final first = await feed();
      expect(first.single.isRead, isFalse);

      await InboxService.markRead('acme', first.single);

      final second = await feed();
      expect(second.single.isRead, isTrue);
    });

    test('marking unread clears it again', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entry = (await feed()).single;
      await InboxService.markRead('acme', entry);
      await InboxService.markUnread('acme', entry);

      expect((await feed()).single.isRead, isFalse);
    });

    test('a dismissed row does not come back', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1'), activityRow(id: 'a2')],
        },
      });

      final entries = await feed();
      await InboxService.dismiss('acme', entries.first);

      expect((await feed()).map((e) => e.id), ['a2']);
    });

    test('undismiss puts it back', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entry = (await feed()).single;
      await InboxService.dismiss('acme', entry);
      expect(await feed(), isEmpty);

      await InboxService.undismiss('acme', entry);
      expect(await feed(), hasLength(1));
    });

    test('read and dismissed are independent marks', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entry = (await feed()).single;
      await InboxService.markRead('acme', entry);
      await InboxService.dismiss('acme', entry);
      await InboxService.undismiss('acme', entry);

      // Setting one must not clear the other — an upsert of the whole row
      // would have.
      expect((await feed()).single.isRead, isTrue);
    });

    test('marks are per workspace', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entry = (await feed()).single;
      await InboxService.dismiss('other-workspace', entry);

      expect(await feed(), hasLength(1));
    });
  });

  group('bulk actions', () {
    test('mark-all-read uses Plane\'s bulk route once, not one call per row',
        () async {
      final adapter = wire({
        '/users/notifications/': [
          notificationRow(id: 'n1'),
          notificationRow(id: 'n2'),
        ],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
        '/mark-all-read/': {'ok': true},
      });

      final entries = await feed();
      adapter.calls.clear();
      await InboxService.markAllRead('acme', entries);

      final markAll =
          adapter.calls.where((c) => c.path.contains('mark-all-read')).toList();
      expect(markAll, hasLength(1));
      // The activity half is a SQLite transaction, not a request.
      expect(adapter.calls, hasLength(1));
      expect((await feed()).where((e) => e.kind == InboxEntryKind.activity),
          everyElement(predicate<InboxEntry>((e) => e.isRead)));
    });

    test('mark-all-read skips the bulk route when nothing is a notification',
        () async {
      final adapter = wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1')],
        },
      });

      final entries = await feed();
      adapter.calls.clear();
      await InboxService.markAllRead('acme', entries);

      expect(adapter.calls, isEmpty);
    });

    test('dismiss-all clears the list', () async {
      wire({
        '/users/notifications/': <Map<String, dynamic>>[],
        '/user-activity/user-1/': {
          'results': [activityRow(id: 'a1'), activityRow(id: 'a2')],
        },
      });

      await InboxService.dismissAll('acme', await feed());

      expect(await feed(), isEmpty);
    });
  });
}
