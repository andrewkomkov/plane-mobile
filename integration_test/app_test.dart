// End-to-end tests that drive the real app on a real device.
//
// This is the Playwright analogue for Flutter: `integration_test` boots the
// actual application binary and drives it through the widget tree, so these
// assert on the app as shipped rather than on widgets built in isolation.
//
//   tool/run_integration_tests.sh [device-id]
//
// Run them through that script rather than by hand: it feeds in the credentials
// the suite needs to sign itself in, and passes `--no-uninstall`.
//
// Running these clears the app's stored session. The run reinstalls the app,
// and an Android reinstall takes `flutter_secure_storage` with it. Two separate
// paths cause it, and knowing which is which saves an afternoon:
//
//   * `flutter test` uninstalls the app once the run ends unless you pass
//     `--no-uninstall`.
//   * `flutter test` also uninstalls-then-reinstalls at launch whenever the APK
//     it built differs from the one on the device. The APK embeds this file, so
//     that is every run in which these tests changed. `--no-uninstall` does not
//     prevent this one.
//
// That used to cost a human login. It no longer does: [ensureSignedIn] re-seeds
// the credentials from `--dart-define` straight into secure storage whenever it
// finds the app signed out, so a wipe costs a re-seed and the suite is safe to
// point at a device whose session you do not want to babysit.
//
// Two things these tests deliberately do NOT cover, because they cannot:
//
//   * The Compose platform views. `AndroidView` is an opaque hole in the
//     Flutter tree — the test can assert the view is mounted, but the Compose
//     content inside it (the native ButtonGroup's own buttons) is unreachable
//     from Dart. `tool/adb_drive.py` covers that boundary at the OS level.
//   * A signed-out launch. The app reads credentials from secure storage, so
//     these run against whatever session the device already holds. A logged-out
//     device lands on the setup screen, which the boot helper detects and fails
//     on by name — the suite cannot sign itself in, and will not try.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:plane_mobile/config/api_client.dart';
import 'package:plane_mobile/config/m3e/motion.dart';
import 'package:plane_mobile/config/secure_storage.dart';
import 'package:plane_mobile/main.dart' as app;
import 'package:plane_mobile/screens/setup/setup_screen.dart';
import 'package:plane_mobile/services/workspace_service.dart';
import 'package:plane_mobile/widgets/app_navbar.dart';
import 'package:plane_mobile/widgets/m3e/app_bar.dart';
import 'package:plane_mobile/widgets/m3e/fab_menu.dart';
import 'package:plane_mobile/widgets/m3e/flexible_app_bar.dart';
import 'package:plane_mobile/widgets/m3e/native.dart';

/// Credentials, compiled in rather than read from disk.
///
/// A Dart test cannot portably read the repo's `.env` — it executes on the
/// device, not on the machine holding the file — and the key must never be
/// committed. `tool/run_integration_tests.sh` bridges the two by handing `.env`
/// to `--dart-define-from-file`, which lands the values here as constants.
const _baseUrl = String.fromEnvironment('PLANE_BASE_URL');
const _apiKey = String.fromEnvironment('PLANE_API_KEY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Everything below pumps on a wall clock rather than calling
  // `pumpAndSettle`. The app's launch spinner and its skeleton shimmers are
  // indefinite animations, so the widget tree never reaches quiescence and
  // `pumpAndSettle` would only ever time out.
  const tick = Duration(milliseconds: 100);

  /// Pumps until [finder] matches, and reports whether it ever did.
  ///
  /// Nothing here waits on a fixed frame count: this is a live client talking
  /// to a real server, so how many frames a screen takes to appear is not a
  /// property of the app.
  Future<bool> pumpUntil(
    WidgetTester tester,
    FinderBase<Element> finder, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final budget = timeout.inMilliseconds ~/ tick.inMilliseconds;
    for (var i = 0; i < budget; i++) {
      if (finder.evaluate().isNotEmpty) return true;
      await tester.pump(tick);
    }
    return finder.evaluate().isNotEmpty;
  }

  /// Pumps until the app stops asking for frames of its own.
  ///
  /// This matters at the *end* of a test, not just the middle. `testWidgets`
  /// unmounts the widget tree the moment the body returns, and several of this
  /// app's loaders call `setState` from an un-guarded `await` continuation (see
  /// the report accompanying this file). If a fetch is still in flight when the
  /// tree goes away, that continuation fires against a defunct State and the
  /// framework charges the resulting error to the test that just passed.
  /// Waiting for the app to go idle keeps the tests honest about their own
  /// failures instead of inheriting the previous test's.
  Future<void> idle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 20),
    int quietTicks = 8,
  }) async {
    final budget = timeout.inMilliseconds ~/ tick.inMilliseconds;
    var quiet = 0;
    for (var i = 0; i < budget && quiet < quietTicks; i++) {
      await tester.pump(tick);
      quiet = tester.binding.hasScheduledFrame ? 0 : quiet + 1;
    }
  }

  /// A bottom-nav destination, addressed the way the nav bar declares it.
  ///
  /// Matching on the widget's own `semanticLabel` rather than on rendered text
  /// is what makes this work at all: an inactive destination renders icon-only,
  /// so there is no text to find. Scoping to [AppNavBar] is equally load
  /// bearing — a screen title such as "Projects" publishes the same semantics
  /// label as the destination that opens it.
  Finder navDestination(String label) => find.descendant(
        of: find.byType(AppNavBar),
        matching: find.byWidgetPredicate(
          (w) => w is M3EPressable && w.semanticLabel == label,
        ),
      );

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(navDestination(label));
    await idle(tester);
  }

  /// Writes credentials into secure storage if the app has none.
  ///
  /// Called before `app.main()`, because `main` decides between the home screen
  /// and the setup screen on the first thing it reads out of secure storage.
  /// Seeding the store directly is deliberate — driving the setup screen's own
  /// form would test the login UI, which is not what these tests are for, and
  /// would put the key through a text field on a real device.
  Future<void> ensureSignedIn() async {
    if (_baseUrl.isEmpty || _apiKey.isEmpty) {
      fail('PLANE_BASE_URL/PLANE_API_KEY were not compiled into this build. '
          'Run the suite through its script, which passes them in:\n'
          '  tool/run_integration_tests.sh 38041FDJH006G1');
    }

    if (!await SecureStorage.isConfigured()) {
      await SecureStorage.saveBaseUrl(_baseUrl);
      await SecureStorage.saveApiKey(_apiKey);
      // The Dio instance is a static cached against the old credentials, and it
      // outlives the widget tree that each test rebuilds.
      ApiClient.reset();
    }

    if ((await SecureStorage.getWorkspaceSlug() ?? '').isEmpty) {
      // The app cannot derive this itself after an API-key sign-in — its own
      // form makes you type the slug (setup_screen.dart `_connectWithApiKey`) —
      // so resolve it from the API rather than hard-coding a workspace.
      final workspaces = await WorkspaceService.getWorkspaces();
      expect(workspaces, isNotEmpty,
          reason: 'the API key resolved no workspaces at $_baseUrl');
      // Prefer one that actually holds projects, so the project group has
      // something to open instead of skipping itself.
      final populated = workspaces.where((w) => w.totalProjects > 0);
      final chosen = populated.isNotEmpty ? populated.first : workspaces.first;
      await SecureStorage.saveWorkspaceSlug(chosen.slug);
      ApiClient.reset();
    }
  }

  /// Boots the app and leaves it on a known screen.
  ///
  /// Each test boots its own copy: `testWidgets` unmounts the tree after every
  /// body, so a suite-wide boot is not something the framework supports.
  Future<void> boot(WidgetTester tester) async {
    await ensureSignedIn();
    app.main();
    final up = await pumpUntil(
      tester,
      find.byWidgetPredicate((w) => w is AppNavBar || w is SetupScreen),
      timeout: const Duration(seconds: 60),
    );
    expect(up, isTrue, reason: 'app never got past its launch spinner');
    // ensureSignedIn should have made this unreachable, so reaching it means the
    // seeded credentials were rejected — an expired or revoked key, not a wiped
    // device. Worth saying out loud rather than leaving as a missing-widget
    // failure three assertions later.
    expect(find.byType(SetupScreen), findsNothing,
        reason: 'app rejected the seeded credentials — is PLANE_API_KEY in '
            '.env still valid for $_baseUrl?');
    // Let the launch fetches finish before the test starts poking the UI, so a
    // later assertion is not racing a list that is still filling in.
    await idle(tester);
  }

  /// Runs [body] against a freshly booted app and lets it go quiet afterwards.
  void appTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      await boot(tester);
      try {
        await body(tester);
      } finally {
        await idle(tester);
      }
    });
  }

  group('shell', () {
    appTest('boots to a signed-in home with the expressive nav bar',
        (tester) async {
      expect(find.byType(AppNavBar), findsOneWidget,
          reason: 'device session missing — sign in before running these');
      expect(find.byType(M3EFlexibleHeaderScaffold), findsOneWidget);
    });

    appTest('every primary destination opens and titles itself',
        (tester) async {
      for (final entry in {
        'Inbox': 'Inbox',
        'My Tasks': 'My issues',
        'Projects': 'Projects',
      }.entries) {
        await goTo(tester, entry.key);
        expect(
          await pumpUntil(tester, find.text(entry.value)),
          isTrue,
          reason: '${entry.key} did not render its title',
        );
      }
    });

    appTest('the nav bar reports which destination is selected',
        (tester) async {
      await goTo(tester, 'Projects');

      final handle = tester.ensureSemantics();
      // A frame has to go by after enabling semantics before the render tree
      // carries any nodes to assert on.
      await tester.pump();

      // The selected flag is what external automation reads to know where it
      // is; losing it silently would strand any script that navigates by state.
      // `isSemantics` rather than `matchesSemantics`: the assertion is about
      // these flags, and it should not start failing the day the framework adds
      // an unrelated one (the node already carries `hasSelectedState` too).
      final projects = tester.getSemantics(navDestination('Projects'));
      final inbox = tester.getSemantics(navDestination('Inbox'));
      expect(projects, isSemantics(isSelected: true, isButton: true));
      // Every other destination has to be un-selected, or "selected" carries no
      // information.
      expect(inbox, isSemantics(isSelected: false, isButton: true));

      // Labels are checked per line, not whole. The *active* destination also
      // renders its label as visible text, and M3EPressable merges that into its
      // own semantics label instead of replacing it, so the node currently reads
      // "Projects\nProjects" — see the report accompanying this file. Splitting
      // still catches a wrong or missing label without freezing the duplication
      // into the expectation.
      expect(projects.label.split('\n').toSet(), {'Projects'});
      expect(inbox.label.split('\n').toSet(), {'Inbox'});
      handle.dispose();
    });
  });

  group('my issues', () {
    appTest('scope button group switches and stays labelled', (tester) async {
      await goTo(tester, 'My Tasks');

      for (final scope in ['Assigned', 'Created', 'All']) {
        expect(find.text(scope), findsOneWidget);
      }

      // Scope is a client-side filter over already-fetched issues, so this
      // changes nothing on the server.
      await tester.tap(find.text('All'));
      await idle(tester);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
    });

    appTest('the FAB menu expands and dismisses without running an action',
        (tester) async {
      await goTo(tester, 'My Tasks');

      expect(find.byType(M3EFabMenu), findsOneWidget);
      expect(find.text('New issue'), findsNothing);

      await tester.tap(find.byType(M3EFabMenu));
      expect(await pumpUntil(tester, find.text('New issue')), isTrue);
      expect(find.text('Display options'), findsOneWidget);

      // Dismissed by tapping the scrim rather than an action: both actions
      // ("New issue", "Display options") would write to the user's real
      // workspace. The action pills stack up the right-hand edge above the FAB,
      // so the top-left corner is scrim and nothing else.
      await tester.tapAt(const Offset(40, 200));
      await idle(tester);
      expect(find.text('New issue'), findsNothing);
    });
  });

  group('project', () {
    /// Opens the first project in the Projects tab, if there is one.
    Future<bool> openFirstProject(WidgetTester tester) async {
      await goTo(tester, 'Projects');
      final rows = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(M3EPressable),
      );
      if (!await pumpUntil(tester, rows)) return false;
      await tester.tap(rows.first);
      // The project screen fetches its own issues; wait that out before
      // asserting, and before the tree is torn down under the fetch.
      await pumpUntil(tester, find.byType(M3EAppBar));
      await idle(tester);
      return true;
    }

    appTest('a project opens with the M3E app bar', (tester) async {
      if (!await openFirstProject(tester)) {
        markTestSkipped('no projects in this workspace');
        return;
      }
      expect(find.byType(M3EAppBar), findsOneWidget);
    });

    appTest('the view switcher is the Compose-backed button group',
        (tester) async {
      if (!await openFirstProject(tester)) {
        markTestSkipped('no projects in this workspace');
        return;
      }

      expect(find.byType(M3ENativeButtonGroup), findsOneWidget);
      if (M3ENative.isAvailable) {
        // On Android the real Compose ButtonGroup is mounted, and its buttons
        // live outside the Dart tree — assert the bridge, not the buttons.
        expect(
          find.descendant(
            of: find.byType(M3ENativeButtonGroup),
            matching: find.byType(AndroidView),
          ),
          findsOneWidget,
        );
      } else {
        expect(find.text('Board'), findsOneWidget);
      }
    });
  });
}
