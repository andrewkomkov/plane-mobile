import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/api_client.dart';
import 'package:plane_mobile/providers/favorites_provider.dart';
import 'package:plane_mobile/screens/cycles/cycle_list_screen.dart';
import 'package:plane_mobile/screens/modules/module_list_screen.dart';
import 'package:plane_mobile/screens/pages/page_detail_screen.dart';
import 'package:plane_mobile/screens/pages/page_list_screen.dart';
import 'package:plane_mobile/screens/views/view_list_screen.dart';

/// A cycle, module, page and view could not be created at all from this app.
///
/// All four flows were written, none had a call site anywhere in the repo, and
/// two of the empty states told the user to create something with nothing to
/// tap. These tests pin the two halves of the fix that can regress silently:
/// the flow is reachable from a public entry point (which is what the project
/// screen's primary action calls), and the empty state offers it — but only to
/// someone whose role the server would accept.
///
/// The role gate itself is pinned in `test/models/member_permissions_test.dart`
/// against the endpoint decorators it mirrors.

/// Answers the list requests these screens make on mount.
///
/// Everything not named 500s. That is deliberate for cycles, modules and pages:
/// `DataCache` swallows a failed fetch and leaves the list empty, which is the
/// branch under test, and a *successful* one would write through to SQLite,
/// which does not exist in a unit test.
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
      return ResponseBody.fromString('{}', 500, headers: _headers);
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _headers);
  }

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Future<void> _serve() async {
  FlutterSecureStorage.setMockInitialValues({
    'plane_base_url': 'https://plane.test',
    'plane_api_key': 'plane_api_test',
  });
  ApiClient.reset();
  final dio = await ApiClient.getInstance();
  dio.httpClientAdapter = _Adapter({
    // Views have no SQLite mirror, so this one can answer honestly.
    '/workspaces/ws/projects/proj-1/views/': <dynamic>[],
  });
}

/// A favourites notifier already settled on the workspace under test.
///
/// Every one of these screens calls `favoritesProvider.notifier.load` from
/// `initState`, and that call writes the notifier's state synchronously the
/// first time it sees a new workspace — which Riverpod refuses to allow during
/// a build. Starting it loaded makes that call return before it writes
/// anything. (The same first-call write happens in the app; it is not something
/// these screens introduced and not something this change can fix from here.)
class _SettledFavorites extends FavoritesNotifier {
  @override
  FavoritesState build() =>
      const FavoritesState(workspaceSlug: 'ws', loaded: true);
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [favoritesProvider.overrideWith(_SettledFavorites.new)],
      child: MaterialApp(home: child),
    );

/// Advance a bounded number of frames.
///
/// `pumpAndSettle` cannot be used here: these screens open on
/// `ProjectListSkeleton`, whose shimmer animates forever, so the frame queue
/// never drains while it is on screen and the pump never returns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_serve);
  tearDown(ApiClient.reset);

  group('the empty state offers the create it tells the user about', () {
    testWidgets('cycles', (tester) async {
      await tester.pumpWidget(_wrap(const CycleListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: true)));
      await _settle(tester);

      expect(find.text('No cycles'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New cycle'), findsOneWidget);
    });

    testWidgets('modules', (tester) async {
      await tester.pumpWidget(_wrap(const ModuleListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: true)));
      await _settle(tester);

      expect(find.text('No modules'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New module'), findsOneWidget);
    });

    testWidgets('pages', (tester) async {
      await tester.pumpWidget(_wrap(const PageListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: true)));
      await _settle(tester);

      expect(find.text('No pages'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New page'), findsOneWidget);
    });

    testWidgets('views', (tester) async {
      await tester.pumpWidget(_wrap(const ViewListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: true)));
      await _settle(tester);

      expect(find.text('No saved views'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New view'), findsOneWidget);
    });
  });

  group('a role the server would refuse is offered nothing', () {
    testWidgets('no button, and no copy promising one', (tester) async {
      await tester.pumpWidget(_wrap(const PageListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: false)));
      await _settle(tester);

      expect(find.text('No pages'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New page'), findsNothing);
      // The old copy said "Create a page to get started" to everybody.
      expect(find.textContaining('Create a page'), findsNothing);
    });

    testWidgets('cycles', (tester) async {
      await tester.pumpWidget(_wrap(const CycleListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: false)));
      await _settle(tester);

      expect(find.widgetWithText(FilledButton, 'New cycle'), findsNothing);
    });

    testWidgets('views', (tester) async {
      await tester.pumpWidget(_wrap(const ViewListScreen(
          workspaceSlug: 'ws', projectId: 'proj-1', canCreate: false)));
      await _settle(tester);

      expect(find.widgetWithText(FilledButton, 'New view'), findsNothing);
    });
  });

  // The project screen's primary app-bar action drives the visible list through
  // its key and calls exactly this method. If it stops opening a form, the app
  // is back where it started.
  group('startCreate opens the form', () {
    testWidgets('cycles', (tester) async {
      final key = GlobalKey<CycleListScreenState>();
      await tester.pumpWidget(_wrap(CycleListScreen(
          key: key,
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          canCreate: true)));
      await _settle(tester);

      key.currentState!.startCreate();
      await _settle(tester);

      expect(find.text('New cycle'), findsWidgets);
      expect(find.text('Start date'), findsOneWidget);
    });

    testWidgets('modules, with the status picker the app uses everywhere else',
        (tester) async {
      final key = GlobalKey<ModuleListScreenState>();
      await tester.pumpWidget(_wrap(ModuleListScreen(
          key: key,
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          canCreate: true)));
      await _settle(tester);

      key.currentState!.startCreate();
      await _settle(tester);

      expect(find.text('New module'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Planned'));
      await _settle(tester);

      // The sheet, not a DropdownButtonFormField menu.
      expect(find.text('Status'), findsOneWidget);
      await tester.tap(find.text('Paused'));
      await _settle(tester);
      expect(find.widgetWithText(OutlinedButton, 'Paused'), findsOneWidget);
    });

    testWidgets('views', (tester) async {
      final key = GlobalKey<ViewListScreenState>();
      await tester.pumpWidget(_wrap(ViewListScreen(
          key: key,
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          canCreate: true)));
      await _settle(tester);

      key.currentState!.startCreate();
      await _settle(tester);

      expect(find.text('View name'), findsOneWidget);
    });

    testWidgets('pages, which is an editor rather than a dialog',
        (tester) async {
      final key = GlobalKey<PageListScreenState>();
      await tester.pumpWidget(_wrap(PageListScreen(
          key: key,
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          canCreate: true)));
      await _settle(tester);

      key.currentState!.startCreate();
      await _settle(tester);

      expect(find.byType(PageEditScreen), findsOneWidget);
    });
  });

  group('the flow refuses to run for a role it was not offered to', () {
    testWidgets('startCreate is a second lock on the same door',
        (tester) async {
      final key = GlobalKey<CycleListScreenState>();
      await tester.pumpWidget(_wrap(CycleListScreen(
          key: key,
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          canCreate: false)));
      await _settle(tester);

      key.currentState!.startCreate();
      await _settle(tester);

      expect(find.text('Start date'), findsNothing);
    });
  });
}
