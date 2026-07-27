import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/screens/home/home_screen.dart';
import 'package:plane_mobile/screens/issues/issue_detail_screen.dart';
import 'package:plane_mobile/screens/project/project_screen.dart';
import 'package:plane_mobile/screens/workspace/home_widgets_screen.dart';
import 'package:plane_mobile/screens/workspace/integrations_screen.dart';

import 'fake_plane.dart';

/// Screens booted against a fake instance, and driven.
///
/// The unit tests answer one service at a time; these answer the whole app, so
/// they reach the two classes of defect that survived every earlier round of
/// checking:
///
/// - **A screen that renders nothing** because a call three layers down 404s.
///   Here that shows up as the expected widget not being on screen.
/// - **A screen with no route to it.** The work-item detail screen was dead
///   for exactly this reason, and the project settings screen existed with no
///   call site anywhere in the app.
///
/// They run in CI, which "verified on a device" never did.
void main() {
  initFakePlaneBinding();

  late FakePlane plane;

  setUp(() async {
    plane = await useFakePlane();
  });

  Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

  /// A taller-than-default surface. Several of these screens are longer than
  /// 800x600 and a control below the fold cannot be tapped.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('the work item detail screen', () {
    testWidgets('shows what it loaded rather than an empty shell',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(const IssueDetailScreen(
        workspaceSlug: FakePlane.slug,
        projectId: FakePlane.projectId,
        issueId: FakePlane.issueId,
        projectIdentifier: 'AUR',
        states: {},
      )));
      await settle(tester);

      // This screen was dead once — it rendered a shell because every call it
      // made 401'd. The title is the cheapest proof that it did not.
      expect(find.text('Fix the header'), findsWidgets);
    });

    testWidgets('a failed load says so instead of drawing an empty item',
        (tester) async {
      tall(tester);
      plane.fail('GET', '/issues/${FakePlane.issueId}/', 500);

      await tester.pumpWidget(wrap(const IssueDetailScreen(
        workspaceSlug: FakePlane.slug,
        projectId: FakePlane.projectId,
        issueId: FakePlane.issueId,
        projectIdentifier: 'AUR',
        states: {},
      )));
      await settle(tester);

      // Being offline and the work item being empty are different answers.
      expect(find.text('Fix the header'), findsNothing);
    });
  });

  group('the project screen', () {
    testWidgets('lists the project work items', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(ProjectScreen(
        workspaceSlug: FakePlane.slug,
        project: Project.fromJson(FakePlane.project),
      )));
      await settle(tester);

      expect(find.text('Fix the header'), findsWidgets);
      expect(find.text('Ship it'), findsWidgets);
    });

    testWidgets('offers a way into settings', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(ProjectScreen(
        workspaceSlug: FakePlane.slug,
        project: Project.fromJson(FakePlane.project),
      )));
      await settle(tester);

      // The settings screen existed with no call site anywhere in the app.
      // This is the assertion that would have caught that.
      expect(find.byIcon(Icons.settings_outlined), findsWidgets);
    });
  });

  group('the home screen', () {
    testWidgets('boots onto the inbox without an unrouted call',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(HomeScreen(onLogout: () {})));
      await settle(tester);

      expect(find.text('Inbox'), findsWidgets);
      // Both halves of the feed, and neither the retired shim route.
      expect(plane.called('/users/notifications/'), isTrue);
      expect(plane.called('/auth/mobile/acme/notifications/'), isFalse);
    });
  });

  group('notes and links', () {
    testWidgets('an empty workspace says so rather than showing a blank list',
        (tester) async {
      tall(tester);
      plane.reply('GET', '/stickies/', <Object>[]);
      plane.reply('GET', '/quick-links/', <Object>[]);

      await tester.pumpWidget(
          wrap(const HomeWidgetsScreen(workspaceSlug: FakePlane.slug)));
      await settle(tester);

      expect(find.text('Nothing pinned yet'), findsOneWidget);
    });

    testWidgets('draws what the workspace holds', (tester) async {
      tall(tester);
      plane.reply('GET', '/stickies/', [
        {
          'id': 's1',
          'name': 'Remember',
          'description_html': '<p>The proxy is the security model</p>',
          'updated_at': '2026-01-02T10:00:00Z',
        }
      ]);
      plane.reply('GET', '/quick-links/', [
        {'id': 'l1', 'title': 'Runbook', 'url': 'https://example.org/runbook'}
      ]);

      await tester.pumpWidget(
          wrap(const HomeWidgetsScreen(workspaceSlug: FakePlane.slug)));
      await settle(tester);

      expect(find.text('Remember'), findsOneWidget);
      expect(find.text('Runbook'), findsOneWidget);
    });
  });

  group('tokens and webhooks', () {
    testWidgets('lists tokens', (tester) async {
      tall(tester);
      plane.reply('GET', '/users/api-tokens/', [
        {
          'id': 't1',
          'label': 'This phone',
          'created_at': '2026-01-01T10:00:00Z',
          'is_active': true,
        }
      ]);
      plane.reply('GET', '/webhooks/', <Object>[]);

      await tester.pumpWidget(
          wrap(const IntegrationsScreen(workspaceSlug: FakePlane.slug)));
      await settle(tester);

      expect(find.text('This phone'), findsOneWidget);
      expect(find.text('Never used'), findsOneWidget);
    });

    testWidgets('a member is told why the webhook list is empty',
        (tester) async {
      tall(tester);
      plane.reply('GET', '/users/api-tokens/', <Object>[]);
      // Plane restricts webhooks to workspace admins.
      plane.fail('GET', '/webhooks/', 403);

      await tester.pumpWidget(
          wrap(const IntegrationsScreen(workspaceSlug: FakePlane.slug)));
      await settle(tester);

      // "None" and "you may not see them" are different answers.
      expect(find.text('Workspace admins only'), findsOneWidget);
    });
  });
}
