import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/m3e/motion.dart';
import 'package:plane_mobile/models/cycle.dart';
import 'package:plane_mobile/models/state.dart';
import 'package:plane_mobile/providers/data_providers.dart';
import 'package:plane_mobile/models/module.dart';
import 'package:plane_mobile/screens/analytics/analytics_screen.dart';
import 'package:plane_mobile/screens/cycles/cycle_detail_screen.dart';
import 'package:plane_mobile/screens/modules/module_detail_screen.dart';
import 'package:plane_mobile/screens/issues/calendar_view.dart';
import 'package:plane_mobile/screens/issues/issue_create_screen.dart';
import 'package:plane_mobile/screens/issues/kanban_board_screen.dart';
import 'package:plane_mobile/screens/issues/spreadsheet_view.dart';
import 'package:plane_mobile/screens/home/menu_tab.dart';
import 'package:plane_mobile/screens/notifications/notification_screen.dart';
import 'package:plane_mobile/screens/pages/page_detail_screen.dart';
import 'package:plane_mobile/screens/search/search_screen.dart';
import 'package:plane_mobile/services/analytics_service.dart';
import 'package:plane_mobile/services/cycle_service.dart';
import 'package:plane_mobile/services/module_service.dart';
import 'package:plane_mobile/services/notification_service.dart';

import '../test_helpers.dart';

/// Accessibility of the screens, asserted against the semantics tree itself.
///
/// These tests count *nodes*, not widgets. `find.bySemanticsLabel` matches
/// widgets, so a control whose label is appended to its child's text — the bug
/// `motion.dart:243-259` documents — happily returns a match while the tree
/// underneath it says the label twice. The only assertion that catches that is
/// an exact comparison against the label a node actually reports, which is what
/// [labels] collects.
///
/// It matters more than usual here because `tool/adb_drive.py` drives the whole
/// app through this tree: a node that is anonymous, duplicated or unreachable
/// is unreachable for the project's own tooling as well as for a screen reader.

List<SemanticsNode> _nodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // The documented replacement, RendererBinding.rootPipelineOwner, does not
  // own the semantics tree under the test binding — reading it yields null and
  // every assertion below silently passes against an empty tree. The
  // deprecated accessor is the one that works here.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) walk(root);
  return out;
}

/// Every label a screen reader would actually be handed.
///
/// Nodes merged into a parent are skipped: they are not focusable and their
/// text is already counted in the parent's label.
List<String> labels(WidgetTester tester) => [
      for (final node in _nodes(tester))
        if (!node.isMergedIntoParent) node.getSemanticsData().label,
    ];

/// The node carrying [label] exactly, which is also the node whose rect is the
/// control's reachable area.
SemanticsNode nodeLabelled(WidgetTester tester, String label) {
  final matches = _nodes(tester)
      .where(
          (n) => !n.isMergedIntoParent && n.getSemanticsData().label == label)
      .toList();
  expect(matches, hasLength(1),
      reason: 'expected exactly one node labelled "$label", got '
          '${matches.length}. All labels: ${labels(tester)}');
  return matches.single;
}

/// Google's and Apple's floor, and the one `M3EIconButton` enforces.
const double _minTarget = 48.0;

/// A cache that already holds its states, so the detail screens never reach
/// past the injected HTTP client.
class _StubCache extends DataCache {
  @override
  Future<void> loadStates(String ws, String pid, {bool force = false}) async {}

  @override
  Map<String, IssueState>? getStates(String ws, String pid) =>
      {'state-1': makeState(name: 'In Progress')};
}

class _Adapter implements HttpClientAdapter {
  final Map<String, dynamic Function()> routes;
  _Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    final handler = routes[options.path];
    if (handler == null) {
      return ResponseBody.fromString('{}', 404, headers: _headers);
    }
    return ResponseBody.fromString(jsonEncode(handler()), 200,
        headers: _headers);
  }

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

void main() {
  group('spreadsheet cells', () {
    Widget wrap() => MaterialApp(
          home: Scaffold(
            body: SpreadsheetView(
              workspaceSlug: 'ws',
              projectId: 'p1',
              projectIdentifier: 'PLM',
              issues: [makeIssue(name: 'Fix the thing', sequenceId: 7)],
              states: {'state-1': makeState(name: 'In Progress')},
              onRefresh: () {},
            ),
          ),
        );

    testWidgets('a property cell names the value once, not twice',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pump();

      // The whole point: the chip draws "In Progress" and the label says it
      // too. Before the exclusion both reached the node.
      nodeLabelled(tester, 'State In Progress, change state of PLM-7');
      expect(labels(tester), isNot(contains('In Progress')));
      nodeLabelled(tester, 'Priority medium, change priority of PLM-7');
      handle.dispose();
    });

    testWidgets('opening an issue is a full cell, not the width of its title',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      final pressable = find.ancestor(
        of: find.text('Fix the thing'),
        matching: find.byType(M3EPressable),
      );
      expect(tester.getSize(pressable.first).height,
          greaterThanOrEqualTo(_minTarget));
    });
  });

  group('calendar day cells', () {
    testWidgets('a day names itself once and does not repeat its number',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarView(
            workspaceSlug: 'ws',
            projectId: 'p1',
            projectIdentifier: 'PLM',
            issues: const [],
            states: const {},
            onRefresh: () {},
          ),
        ),
      ));
      await tester.pump();

      final now = DateTime.now();
      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      nodeLabelled(tester, 'Select day $key, no issues');
      // The cell draws a bare "1"; if it reached the tree the label above
      // would be a substring rather than the whole node.
      expect(labels(tester), isNot(contains('1')));
      handle.dispose();
    });
  });

  group('kanban column', () {
    testWidgets('names the drop target without swallowing its cards',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: KanbanBoardScreen(
            workspaceSlug: 'ws',
            projectId: 'p1',
            projectIdentifier: 'PLM',
            issues: [makeIssue(name: 'Card one')],
            states: {'state-1': makeState(name: 'In Progress')},
            onRefresh: () {},
          ),
        ),
      ));
      await tester.pump();

      nodeLabelled(tester, 'Column In Progress, 1 issues');
      // The regression this guards: excluding the subtree would have been the
      // obvious fix and would have erased every card in the column.
      expect(labels(tester).where((l) => l.contains('Card one')), hasLength(1));
      handle.dispose();
    });
  });

  group('compose screen', () {
    final states = {'state-1': makeState(id: 'state-1', name: 'Todo')};

    Widget wrap() => MaterialApp(
          home: IssueCreateScreen(
            workspaceSlug: 'ws',
            projectId: 'p1',
            states: states,
          ),
        );

    testWidgets('the picker cards say what they are and what they hold',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pump();

      nodeLabelled(tester, 'Status: Todo. Change status');
      nodeLabelled(tester, 'Priority: Medium. Change priority');
      // Both were drawn as an overline plus a value with no button role.
      expect(labels(tester), isNot(contains('STATUS')));
      expect(labels(tester), isNot(contains('Todo')));
      handle.dispose();
    });

    testWidgets('the app bar pills are a fingertip tall', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pump();

      // The node's rect is the reachable area, which is the thing the 48dp
      // floor is about — the painted pill stays at its designed 38dp.
      expect(nodeLabelled(tester, 'Save as draft').rect.height,
          greaterThanOrEqualTo(_minTarget));
      expect(nodeLabelled(tester, 'Create work item').rect.height,
          greaterThanOrEqualTo(_minTarget));
      handle.dispose();
    });
  });

  group('analytics', () {
    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'https://plane.test/api'));
      dio.httpClientAdapter = _Adapter({
        '/workspaces/acme/advance-analytics/': () => {
              'total_work_items': {'count': 12},
              'backlog_work_items': {'count': 3},
              'un_started_work_items': {'count': 1},
              'started_work_items': {'count': 4},
              'completed_work_items': {'count': 4},
            },
        '/workspaces/acme/advance-analytics-charts/': () => {
              'data': [
                {'key': 'urgent', 'count': 8},
              ],
              'schema': <String, dynamic>{},
            },
        '/workspaces/acme/advance-analytics-stats/': () => [
              {
                'project_id': 'p1',
                'project__name': 'Alpha',
                'started_work_items': 4,
                'completed_work_items': 4,
              },
            ],
      });
      AnalyticsService.debugClient = dio;
    });

    tearDown(() => AnalyticsService.debugClient = null);

    testWidgets('a stat card is one node, not a label plus its own text',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: AnalyticsScreen(workspaceSlug: 'acme')),
      ));
      await tester.pumpAndSettle();

      nodeLabelled(tester, 'Total work items: 12, from server');
      // The card draws all three of these; the label already carries them.
      expect(labels(tester), isNot(contains('Total work items')));
      expect(labels(tester), isNot(contains('from server')));
      expect(labels(tester), isNot(contains('12')));
      handle.dispose();
    });

    testWidgets('the provenance note is announced once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: AnalyticsScreen(workspaceSlug: 'acme')),
      ));
      await tester.pumpAndSettle();

      // Exact, not `contains`: the bug is the sentence reaching the node
      // twice, once as the label and once as the Text beneath it, and a
      // substring match is satisfied by either.
      nodeLabelled(
        tester,
        'Computed by Plane over the projects you belong to. Nothing on this '
        'screen is counted on the device. The server did not answer for the '
        'overdue count, shown as unavailable below.',
      );
      handle.dispose();
    });
  });

  group('notification feed', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'read' ? 'acme' : null,
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://plane.test'));
      dio.httpClientAdapter = _Adapter({
        '/workspaces/acme/users/notifications/': () => [
              {
                'id': 'n1',
                'title': 'Ada commented on PLM-7',
                'entity_name': 'Fix the thing',
                'created_at': '2026-07-20T10:00:00Z',
                'data': <String, dynamic>{},
              },
            ],
      });
      NotificationService.debugClient = dio;
    });

    tearDown(() {
      NotificationService.debugClient = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    testWidgets('a row names itself and archiving is a real control',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: NotificationScreen(workspaceSlug: 'acme')),
      ));
      await tester.pumpAndSettle();

      // The row was an unlabelled M3EPressable: an anonymous node with the
      // title, entity and timestamp scattered into unrelated children.
      final row = nodeLabelled(
        tester,
        'Ada commented on PLM-7, Fix the thing, 6d, unread',
      );
      expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      // Archiving existed only as a swipe, which leaves no node at all — so
      // its absence could not even be reported.
      final archive = nodeLabelled(tester, 'Archive Ada commented on PLM-7');
      expect(archive.rect.height, greaterThanOrEqualTo(_minTarget));
      expect(archive.rect.width, greaterThanOrEqualTo(_minTarget));
      handle.dispose();
    });
  });

  group('cycle and module detail', () {
    final issueJson = {
      'id': 'i1',
      'name': 'Fix the thing',
      'priority': 'medium',
      'sequence_id': 7,
      'created_at': '2026-07-01T00:00:00Z',
      'updated_at': '2026-07-01T00:00:00Z',
    };

    tearDown(() {
      CycleService.debugClient = null;
      ModuleService.debugClient = null;
    });

    /// The screens also await the shared cache for states, which would reach
    /// for sqflite and then the network. Overriding the provider keeps the
    /// test to the one request the injected client answers.
    final overrides = [dataCacheProvider.overrideWithValue(_StubCache())];

    Dio serving(String path) {
      final dio = Dio(BaseOptions(baseUrl: 'https://plane.test'));
      dio.httpClientAdapter = _Adapter({
        path: () => [issueJson]
      });
      return dio;
    }

    testWidgets('removing an issue from a cycle is not swipe-only',
        (tester) async {
      CycleService.debugClient =
          serving('/workspaces/acme/projects/p1/cycles/c1/cycle-issues/');
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: CycleDetailScreen(
            workspaceSlug: 'acme',
            projectId: 'p1',
            cycle: Cycle(
              id: 'c1',
              name: 'Sprint 4',
              totalIssues: 1,
              completedIssues: 0,
              createdAt: DateTime(2026, 7, 1),
            ),
          ),
        ),
      ));
      // Not pumpAndSettle: the loading indicator animates forever, so
      // settling times out before the injected client has answered. Let real
      // async run between frames instead.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      final remove =
          nodeLabelled(tester, 'Remove Fix the thing from this cycle');
      expect(remove.rect.height, greaterThanOrEqualTo(_minTarget));
      // The overflow used to be called "More" on this screen and on the
      // module one, so the two collided across a flow.
      nodeLabelled(tester, 'More actions for cycle Sprint 4');
      expect(labels(tester), isNot(contains('More')));
      handle.dispose();
    });

    testWidgets('removing an issue from a module is not swipe-only',
        (tester) async {
      ModuleService.debugClient =
          serving('/workspaces/acme/projects/p1/modules/m1/issues/');
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: ModuleDetailScreen(
            workspaceSlug: 'acme',
            projectId: 'p1',
            module: Module(
              id: 'm1',
              name: 'Billing',
              totalIssues: 1,
              completedIssues: 0,
              createdAt: DateTime(2026, 7, 1),
            ),
          ),
        ),
      ));
      // Not pumpAndSettle: the loading indicator animates forever, so
      // settling times out before the injected client has answered. Let real
      // async run between frames instead.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      final remove =
          nodeLabelled(tester, 'Remove Fix the thing from this module');
      expect(remove.rect.height, greaterThanOrEqualTo(_minTarget));
      nodeLabelled(tester, 'More actions for module Billing');
      expect(labels(tester), isNot(contains('More')));
      handle.dispose();
    });
  });

  group('page editor', () {
    testWidgets('the save pill is a fingertip tall', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: PageEditScreen(
          workspaceSlug: 'acme',
          projectId: 'p1',
          initialName: 'Notes',
          initialHtml: '',
        ),
      ));
      await tester.pump();

      expect(nodeLabelled(tester, 'Save').rect.height,
          greaterThanOrEqualTo(_minTarget));
      handle.dispose();
    });
  });

  group('menu tab', () {
    testWidgets('the workspace switcher is named and reachable',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MenuTab(workspaceSlug: 'acme', onLogout: () {}),
          ),
        ),
      ));
      await tester.pump();

      final switcher = nodeLabelled(tester, 'Switch workspace');
      // "Plane" is drawn inside the control; before the exclusion it was
      // appended to the label and reached the tree as a second name.
      expect(labels(tester), isNot(contains('Plane')));
      expect(
          switcher.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(switcher.rect.height, greaterThanOrEqualTo(_minTarget));
      handle.dispose();
    });
  });

  group('search screen', () {
    testWidgets('a pushed search screen offers a way back', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('behind')),
        ),
      ));

      key.currentState!.push(MaterialPageRoute(
        builder: (_) => const SearchScreen(workspaceSlug: 'acme'),
      ));
      await tester.pumpAndSettle();

      // Every other pushed screen gets this from M3EAppBar; this one builds a
      // raw PreferredSize and had nothing but the system gesture.
      nodeLabelled(tester, 'Back');
      handle.dispose();
    });

    testWidgets('an inline search screen does not offer one', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SearchScreen(workspaceSlug: 'acme')),
      ));
      await tester.pumpAndSettle();

      expect(labels(tester), isNot(contains('Back')));
      handle.dispose();
    });
  });
}
