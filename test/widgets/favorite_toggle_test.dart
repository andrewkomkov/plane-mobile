import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/favorite.dart';
import 'package:plane_mobile/providers/favorites_provider.dart';
import 'package:plane_mobile/services/favorite_service.dart';
import 'package:plane_mobile/widgets/favorite_toggle.dart';

/// A server that answers whatever the test told it to, and remembers what was
/// asked of it.
class _Server implements HttpClientAdapter {
  /// Rows the workspace list hands back.
  List<Map<String, dynamic>> favorites = [];

  /// Set to fail every write, which is what the revert path needs.
  bool refuseWrites = false;

  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    if (options.method != 'GET' && refuseWrites) {
      return ResponseBody.fromString('{"error":"denied"}', 400,
          headers: _headers);
    }
    if (options.method == 'GET') {
      return ResponseBody.fromString(_encode(favorites), 200,
          headers: _headers);
    }
    if (options.method == 'POST') {
      return ResponseBody.fromString(
        '{"id":"fav-new","entity_type":"cycle",'
        '"entity_identifier":"c1","project_id":"p1"}',
        200,
        headers: _headers,
      );
    }
    return ResponseBody.fromString('', 204, headers: _headers);
  }

  String _encode(List<Map<String, dynamic>> rows) => '[${rows.map((r) => '''
{"id":"${r['id']}","entity_type":"${r['entity_type']}",
 "entity_identifier":"${r['entity_identifier']}","is_folder":false}''').join(',')}]';

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;

  setUp(() {
    server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
    dio.httpClientAdapter = server;
    FavoriteService.debugClient = dio;
  });

  tearDown(() {
    FavoriteService.debugClient = null;
  });

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  Widget toggle() => const FavoriteToggle(
        workspaceSlug: 'acme',
        entity: FavoriteEntity.cycle,
        entityId: 'c1',
        entityName: 'Sprint 4',
        projectId: 'p1',
      );

  group('FavoriteToggle', () {
    testWidgets('names the action and the thing it acts on', (tester) async {
      // Rows repeat. "Add to favorites" on its own would give a list of
      // identical controls to a screen reader and to tool/adb_drive.py.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(toggle()));

      expect(
        find.bySemanticsLabel('Add cycle Sprint 4 to favorites'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('draws an outline star until it is favourited', (tester) async {
      await tester.pumpWidget(wrap(toggle()));

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('fills before the server has answered', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(toggle()));

      await tester.tap(find.byType(FavoriteToggle));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(
        find.bySemanticsLabel('Remove cycle Sprint 4 from favorites'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('snaps back and says so when the write is refused',
        (tester) async {
      server.refuseWrites = true;
      await tester.pumpWidget(wrap(toggle()));

      await tester.tap(find.byType(FavoriteToggle));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(
        find.text('Could not update favorites for Sprint 4'),
        findsOneWidget,
      );
    });

    testWidgets('shows the state the workspace already held', (tester) async {
      server.favorites = [
        {'id': 'fav-1', 'entity_type': 'cycle', 'entity_identifier': 'c1'},
      ];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Real async: the fake clock a widget test runs on never advances the
      // timers Dio's response decoding waits on unless something is pumping.
      await tester.runAsync(
          () => container.read(favoritesProvider.notifier).load('acme'));

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: Center(child: toggle()))),
      ));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('unstars through the favourite row id, not the entity id',
        (tester) async {
      // The generic collection deletes by the id of the UserFavorite row. This
      // is the assertion that stops that being quietly swapped for the cycle id
      // — which would 404 rather than fail loudly.
      server.favorites = [
        {'id': 'fav-1', 'entity_type': 'cycle', 'entity_identifier': 'c1'},
      ];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Real async: the fake clock a widget test runs on never advances the
      // timers Dio's response decoding waits on unless something is pumping.
      await tester.runAsync(
          () => container.read(favoritesProvider.notifier).load('acme'));
      server.requests.clear();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: Center(child: toggle()))),
      ));
      await tester.tap(find.byType(FavoriteToggle));
      await tester.pumpAndSettle();

      expect(
        server.requests,
        contains('DELETE /workspaces/acme/user-favorites/fav-1/'),
      );
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });
  });

  group('FavoritesNotifier', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('a failed read leaves a working, unstarred list', () async {
      // A list screen that cannot say which rows are starred is still a list
      // screen. Nothing raises out of here.
      FavoriteService.debugClient =
          Dio(BaseOptions(baseUrl: 'https://plane.test/api'))
            ..httpClientAdapter = _BrokenAdapter();
      final c = container();

      await c.read(favoritesProvider.notifier).load('acme');

      expect(c.read(favoritesProvider).ids, isEmpty);
      expect(c.read(favoritesProvider).loaded, isFalse);
    });

    test('a second workspace does not inherit the first one\'s stars',
        () async {
      server.favorites = [
        {'id': 'fav-1', 'entity_type': 'cycle', 'entity_identifier': 'c1'},
      ];
      final c = container();
      await c.read(favoritesProvider.notifier).load('acme');
      expect(c.read(favoritesProvider).isFavorite(FavoriteEntity.cycle, 'c1'),
          isTrue);

      server.favorites = [];
      await c.read(favoritesProvider.notifier).load('other');

      expect(c.read(favoritesProvider).isFavorite(FavoriteEntity.cycle, 'c1'),
          isFalse);
      expect(c.read(favoritesProvider).workspaceSlug, 'other');
    });

    test('a tap arriving mid-flight is dropped, not sent with no id', () async {
      // Between the star lighting up and the create answering there is no
      // favourite id to delete by. The second tap has to go nowhere rather
      // than invent one.
      final c = container();
      final notifier = c.read(favoritesProvider.notifier);

      final first = notifier.toggle('acme',
          entity: FavoriteEntity.cycle, entityId: 'c1', projectId: 'p1');
      final second = await notifier.toggle('acme',
          entity: FavoriteEntity.cycle, entityId: 'c1', projectId: 'p1');
      await first;

      expect(second, isTrue);
      expect(c.read(favoritesProvider).isFavorite(FavoriteEntity.cycle, 'c1'),
          isTrue);
      expect(
        server.requests.where((r) => r.startsWith('DELETE')),
        isEmpty,
      );
    });

    test('keeps the row id the create answered with', () async {
      final c = container();
      await c.read(favoritesProvider.notifier).toggle('acme',
          entity: FavoriteEntity.cycle, entityId: 'c1', projectId: 'p1');

      expect(c.read(favoritesProvider).ids['cycle:c1'], 'fav-new');
    });
  });

  group('favoritesFirst', () {
    test('lifts favourites without disturbing the rest of the order', () {
      const state = FavoritesState(ids: {'project:b': 'f1'});

      expect(
        state.favoritesFirst(FavoriteEntity.project, ['a', 'b', 'c'], (s) => s),
        ['b', 'a', 'c'],
      );
    });

    test('leaves a list with nothing starred exactly as it was', () {
      const state = FavoritesState(ids: {'cycle:z': 'f1'});

      final items = ['a', 'b'];
      expect(
        state.favoritesFirst(FavoriteEntity.cycle, items, (s) => s),
        same(items),
      );
    });

    test('does not confuse one entity type with another', () {
      // Keys carry the type, so a cycle and a page that share an id — which
      // they never will, but the map cannot know that — stay apart.
      const state = FavoritesState(ids: {'page:x': 'f1'});

      expect(
        state.favoritesFirst(FavoriteEntity.cycle, ['w', 'x'], (s) => s),
        ['w', 'x'],
      );
    });
  });
}

class _BrokenAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      Future.error(StateError('offline'));

  @override
  void close({bool force = false}) {}
}
