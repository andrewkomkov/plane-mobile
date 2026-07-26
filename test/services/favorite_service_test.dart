import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/favorite.dart';
import 'package:plane_mobile/services/favorite_service.dart';

/// Answers requests from a routing table instead of a network.
///
/// Keyed by method and path both, because the favourites collection serves GET
/// and POST on one path and the difference is the whole point of the endpoint.
class _FakeAdapter implements HttpClientAdapter {
  /// "METHOD path" -> a body, or an int status code to fail with.
  final Map<String, dynamic Function(dynamic body)> routes;

  /// Every request made, in order.
  final List<RequestOptions> calls = [];

  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return ResponseBody.fromString('{"error":"no route"}', 404,
          headers: _jsonHeaders);
    }
    final result = handler(options.data);
    if (result is int) {
      return ResponseBody.fromString('{"error":"denied"}', result,
          headers: _jsonHeaders);
    }
    if (result == null) {
      return ResponseBody.fromString('', 204, headers: _jsonHeaders);
    }
    return ResponseBody.fromString(jsonEncode(result), 200,
        headers: _jsonHeaders);
  }

  static const _jsonHeaders = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> row(
  String id,
  String type,
  String? entityId, {
  bool isFolder = false,
  String? projectId,
}) =>
    {
      'id': id,
      'entity_type': type,
      'entity_identifier': entityId,
      'is_folder': isFolder,
      'project_id': projectId,
    };

void main() {
  tearDown(() {
    FavoriteService.debugClient = null;
  });

  group('getFavorites', () {
    test('reads the whole workspace from one bare list', () async {
      final adapter = _FakeAdapter({
        'GET /workspaces/acme/user-favorites/': (_) => [
              row('f1', 'cycle', 'c1', projectId: 'p1'),
              row('f2', 'project', 'p2', projectId: 'p2'),
            ],
      });
      FavoriteService.debugClient = _dioWith(adapter);

      final favorites = await FavoriteService.getFavorites('acme');

      expect(favorites.map((f) => f.key), ['cycle:c1', 'project:p2']);
      expect(adapter.calls, hasLength(1));
    });

    test('follows folders, which the top-level answer leaves out', () async {
      // `WorkspaceFavoriteEndpoint.get` filters `parent__isnull=True`, so a
      // favourite the user dragged into a folder on the web is simply absent.
      // Left there, its row would draw unstarred.
      final adapter = _FakeAdapter({
        'GET /workspaces/acme/user-favorites/': (_) => [
              row('f1', 'module', 'm1', projectId: 'p1'),
              row('folder-1', 'folder', null, isFolder: true),
            ],
        'GET /workspaces/acme/user-favorites/folder-1/group/': (_) => [
              row('f2', 'page', 'pg1', projectId: 'p1'),
            ],
      });
      FavoriteService.debugClient = _dioWith(adapter);

      final favorites = await FavoriteService.getFavorites('acme');

      expect(
        favorites.map((f) => f.key).whereType<String>(),
        containsAll(['module:m1', 'page:pg1']),
      );
    });

    test('a folder that will not open costs only what is inside it', () async {
      final adapter = _FakeAdapter({
        'GET /workspaces/acme/user-favorites/': (_) => [
              row('f1', 'view', 'v1', projectId: 'p1'),
              row('folder-1', 'folder', null, isFolder: true),
            ],
        'GET /workspaces/acme/user-favorites/folder-1/group/': (_) => 500,
      });
      FavoriteService.debugClient = _dioWith(adapter);

      final favorites = await FavoriteService.getFavorites('acme');

      expect(favorites.map((f) => f.key), contains('view:v1'));
    });

    test('costs no extra request when there are no folders', () async {
      final adapter = _FakeAdapter({
        'GET /workspaces/acme/user-favorites/': (_) => [
              row('f1', 'cycle', 'c1', projectId: 'p1'),
            ],
      });
      FavoriteService.debugClient = _dioWith(adapter);

      await FavoriteService.getFavorites('acme');

      expect(adapter.calls, hasLength(1));
    });

    test('reads a paginated envelope too', () {
      // No favourites route paginates today. Roughly a third of the routes
      // checked in this codebase did something their name did not suggest, so
      // the parser reads both shapes rather than trusting one.
      final parsed = FavoriteService.parseFavorites({
        'results': [row('f1', 'cycle', 'c1')],
      });

      expect(parsed.single.key, 'cycle:c1');
    });
  });

  group('addFavorite', () {
    test('sends the entity type, the entity id and the project', () async {
      // `UserFavoriteSerializer` marks project_id read-only, so the view lifts
      // it out of the body by hand. Omitted, the favourite is written with no
      // project and the workspace list never returns it again.
      late Map<String, dynamic> sent;
      final adapter = _FakeAdapter({
        'POST /workspaces/acme/user-favorites/': (body) {
          sent = Map<String, dynamic>.from(body as Map);
          return row('f9', 'cycle', 'c1', projectId: 'p1');
        },
      });
      FavoriteService.debugClient = _dioWith(adapter);

      final created = await FavoriteService.addFavorite(
        'acme',
        entity: FavoriteEntity.cycle,
        entityId: 'c1',
        projectId: 'p1',
      );

      expect(sent, {
        'entity_type': 'cycle',
        'entity_identifier': 'c1',
        'project_id': 'p1',
      });
      expect(created.id, 'f9');
    });

    test('answers with the row id, which is what removal needs', () async {
      final adapter = _FakeAdapter({
        'POST /workspaces/acme/user-favorites/': (_) =>
            row('f9', 'page', 'pg1', projectId: 'p1'),
      });
      FavoriteService.debugClient = _dioWith(adapter);

      final created = await FavoriteService.addFavorite(
        'acme',
        entity: FavoriteEntity.page,
        entityId: 'pg1',
        projectId: 'p1',
      );

      expect(created.id, 'f9');
      expect(created.entityIdentifier, 'pg1');
    });
  });

  test('removeFavorite deletes by the favourite id, not the entity id',
      () async {
    final adapter = _FakeAdapter({
      'DELETE /workspaces/acme/user-favorites/f9/': (_) => null,
    });
    FavoriteService.debugClient = _dioWith(adapter);

    await FavoriteService.removeFavorite('acme', 'f9');

    expect(adapter.calls.single.path, '/workspaces/acme/user-favorites/f9/');
    expect(adapter.calls.single.method, 'DELETE');
  });
}
