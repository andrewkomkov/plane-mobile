import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/issue_row.dart';
import 'package:plane_mobile/widgets/plane_row.dart';
import '../test_helpers.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('IssueRow', () {
    testWidgets('displays issue name', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(name: 'Login bug'),
          onTap: () {},
        ),
      ));

      expect(find.text('Login bug'), findsOneWidget);
    });

    testWidgets('displays identifier and sequence id', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(sequenceId: 42),
          identifier: 'PROJ',
          onTap: () {},
        ),
      ));

      expect(find.text('PROJ-42'), findsOneWidget);
    });

    testWidgets('does not display identifier when null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(sequenceId: 42),
          identifier: null,
          onTap: () {},
        ),
      ));

      expect(find.textContaining('42'), findsNothing);
    });

    testWidgets(
        'falls back to the bare sequence id when a screen asks for the '
        'id but has no project identifier', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(sequenceId: 42),
          showId: true,
          onTap: () {},
        ),
      ));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays sub-issues count when > 0', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(subIssuesCount: 5),
          showSubIssues: true,
          onTap: () {},
        ),
      ));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does not display sub-issues count when 0', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(subIssuesCount: 0),
          showSubIssues: true,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.subdirectory_arrow_right), findsNothing);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(),
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(IssueRow));
      expect(tapped, isTrue);
    });

    testWidgets('shows overdue icon when issue is overdue', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(targetDate: '2020-01-01'),
          showDueDate: true,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('does not show overdue icon when not overdue', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(targetDate: '2099-12-31'),
          showDueDate: true,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('renders label pills only when asked for', (tester) async {
      final issue = makeIssue(labels: ['label-1']);
      final labels = [makeLabel(name: 'Bug')];

      await tester.pumpWidget(wrapWidget(
        IssueRow(issue: issue, allLabels: labels, onTap: () {}),
      ));
      expect(find.text('Bug'), findsNothing);

      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: issue,
          allLabels: labels,
          showLabels: true,
          onTap: () {},
        ),
      ));
      expect(find.text('Bug'), findsOneWidget);
    });

    testWidgets('an unread row takes the emphasized title cut', (tester) async {
      Future<FontWeight?> weightOf({required bool unread}) async {
        await tester.pumpWidget(wrapWidget(
          IssueRow(
            issue: makeIssue(name: 'Someone commented'),
            subtitle: 'commented on this',
            unread: unread,
            onTap: () {},
          ),
        ));
        return tester
            .widget<Text>(find.text('Someone commented'))
            .style
            ?.fontWeight;
      }

      final quiet = await weightOf(unread: false);
      final loud = await weightOf(unread: true);
      expect(loud!.value, greaterThan(quiet!.value));
    });

    group('accessibility label', () {
      testWidgets(
          'leads with the identifier, then the name, then everything '
          'the row draws', (tester) async {
        // The row's label replaces the semantics of everything under it, so a
        // property that is drawn but not named is a property nobody using a
        // screen reader — or `tool/adb_drive.py` — can see at all.
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(wrapWidget(
          IssueRow(
            issue: makeIssue(
              name: 'Login bug',
              sequenceId: 415,
              priority: 'urgent',
              assignees: ['member-1'],
              labels: ['label-1'],
              subIssuesCount: 2,
            ),
            identifier: 'AFS',
            state: makeState(name: 'In Progress'),
            showLabels: true,
            showAssignee: true,
            showSubIssues: true,
            allLabels: [makeLabel(name: 'Bug')],
            allMembers: [makeMember(displayName: 'John Doe')],
            onTap: () {},
          ),
        ));

        expect(
          find.bySemanticsLabel('AFS-415, Login bug, state In Progress, '
              'priority urgent, labels Bug, assigned to John Doe, '
              '2 sub-issues'),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('leaves out a property the row is not showing',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(wrapWidget(
          IssueRow(
            issue: makeIssue(name: 'Login bug', priority: 'urgent'),
            state: makeState(name: 'In Progress'),
            showPriority: false,
            showState: false,
            onTap: () {},
          ),
        ));

        expect(find.bySemanticsLabel('Login bug'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('takes the extra clauses a board card needs', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(wrapWidget(
          SizedBox(
            width: 280,
            child: IssueRow(
              issue: makeIssue(name: 'Login bug', priority: 'none'),
              identifier: 'AFS',
              density: PlaneRowDensity.card,
              showState: false,
              semanticExtras: const ['in Todo'],
              onTap: () {},
            ),
          ),
        ));

        expect(
            find.bySemanticsLabel('AFS-1, Login bug, in Todo'), findsOneWidget);
        handle.dispose();
      });
    });
  });
}
