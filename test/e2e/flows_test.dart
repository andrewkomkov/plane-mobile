import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/state.dart';
import 'package:plane_mobile/screens/issues/issue_create_screen.dart';

import 'fake_plane.dart';

/// Flows, not renders.
///
/// `screens_reachable_test.dart` asks whether a screen draws what it loaded.
/// These ask what the app *sends* when someone uses it — which is where the
/// interesting mistakes are, because a payload the server quietly discards
/// looks exactly like one it accepted.
void main() {
  initFakePlaneBinding();

  late FakePlane plane;

  setUp(() async {
    plane = await useFakePlane();
  });

  Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The request the app made to [pattern] with [method], or null.
  Map<String, dynamic>? bodyOf(String method, String pattern) {
    for (final call in plane.calls.reversed) {
      if (call.method != method) continue;
      if (!call.path.contains(pattern)) continue;
      final data = call.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    }
    return null;
  }

  group('composing a work item', () {
    testWidgets('sends every field, empty ones included', (tester) async {
      tall(tester);
      plane.reply('POST', '/issues/', FakePlane.issue(id: 'new-1'));

      await tester.pumpWidget(wrap(IssueCreateScreen(
        workspaceSlug: FakePlane.slug,
        projectId: FakePlane.projectId,
        states: {
          'state-todo': IssueState(
            id: 'state-todo',
            name: 'Todo',
            color: '#3b82f6',
            group: 'unstarted',
            sequence: 1,
          ),
        },
      )));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Something to do');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await settle(tester);

      final body = bodyOf('POST', '/issues/');
      expect(body, isNotNull);
      expect(body!['name'], 'Something to do');
      // Empty and absent are different to Plane: an omitted key leaves the
      // previous value standing, which is what made clearing a draft's
      // assignees a silent no-op.
      expect(body.containsKey('assignee_ids'), isTrue);
      expect(body.containsKey('label_ids'), isTrue);
      expect(body['assignee_ids'], isEmpty);
    });

    testWidgets('refuses to send a work item with no title', (tester) async {
      tall(tester);

      await tester.pumpWidget(wrap(IssueCreateScreen(
        workspaceSlug: FakePlane.slug,
        projectId: FakePlane.projectId,
        states: const {},
      )));
      await settle(tester);

      await tester.tap(find.text('Create'));
      await settle(tester);

      // The server would refuse it too; saying so here costs nothing and a
      // round trip.
      expect(plane.calls.any((c) => c.method == 'POST'), isFalse);
    });
  });

  // Two flows that are not here, and why: changing a work item's state, and
  // adding a note. Both go through a bottom sheet, and driving one from a test
  // asserts the sheet's plumbing rather than the contract with the server —
  // which the service tests already pin down (`inbox_service_test.dart`,
  // `bulk_service_test.dart`). The payloads above are the part no other test
  // covers, because they are assembled by a screen.
}
