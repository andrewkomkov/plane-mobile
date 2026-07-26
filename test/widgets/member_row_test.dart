import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/member.dart';
import 'package:plane_mobile/widgets/member_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Member jane() => Member(
        id: 'user-1',
        displayName: 'jane',
        email: 'jane@example.com',
        firstName: 'Jane',
        lastName: 'Doe',
      );

  group('MemberRow', () {
    testWidgets('shows the role beside the person', (tester) async {
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.admin,
      )));

      expect(find.text('jane'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('shows no role rather than guessing one', (tester) async {
      // A project membership joined against a workspace list that failed to
      // load has a role, but a row built from a bare Member does not — and a
      // wrong role here is worse than a missing one.
      await tester.pumpWidget(wrap(MemberRow(member: jane())));

      expect(find.text('Admin'), findsNothing);
      expect(find.text('Guest'), findsNothing);
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('marks the signed-in user', (tester) async {
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.member,
        isSelf: true,
      )));

      expect(find.text('jane (you)'), findsOneWidget);
    });

    testWidgets('offers no overflow button when no action is permitted',
        (tester) async {
      // This is the gate made visible: an empty action list means the caller
      // may do nothing to this person, so there must be nothing to press.
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.admin,
        actions: const [],
      )));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('opens the permitted actions and fires the chosen one',
        (tester) async {
      var removed = false;
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.member,
        actions: [
          MemberAction(
            label: 'Remove from project',
            icon: Icons.person_remove_outlined,
            destructive: true,
            onSelected: () => removed = true,
          ),
        ],
      )));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Remove from project'), findsOneWidget);

      await tester.tap(find.text('Remove from project'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('names itself and its role for the accessibility tree',
        (tester) async {
      // PlaneRow replaces its subtree's semantics with the label it is given,
      // so anything the row draws is invisible to `tool/adb_drive.py` unless
      // the label repeats it.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.admin,
        isSelf: true,
      )));

      expect(
        find.bySemanticsLabel('jane, you, Admin, jane@example.com'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the overflow button keeps its own name', (tester) async {
      // It sits in PlaneRow's trailing slot precisely so that it stays outside
      // the row's semantics node and remains addressable by label.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(MemberRow(
        member: jane(),
        role: MemberRole.admin,
        actions: [
          MemberAction(
            label: 'Change role',
            icon: Icons.badge_outlined,
            onSelected: () {},
          ),
        ],
      )));

      expect(find.bySemanticsLabel('Manage jane'), findsOneWidget);
      handle.dispose();
    });
  });

  group('showRolePicker', () {
    testWidgets('offers only the roles it was handed', (tester) async {
      // The narrowing happens in MemberPermissions; by the time it reaches the
      // picker there is nothing left to disable or explain away.
      int? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showRolePicker(
                  context,
                  title: 'Role for jane',
                  allowed: const [MemberRole.guest],
                  current: MemberRole.guest,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Member'), findsNothing);

      await tester.tap(find.text('Guest'));
      await tester.pumpAndSettle();
      expect(picked, MemberRole.guest);
    });
  });

  group('confirmMemberAction', () {
    testWidgets('a dismissed dialog is not a confirmation', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await confirmMemberAction(
                  context,
                  title: 'Remove jane?',
                  message: 'She loses access.',
                  confirmLabel: 'Remove',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
