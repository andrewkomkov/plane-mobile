import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/issue_row.dart';
import 'package:plane_mobile/models/state.dart';
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

    testWidgets('displays sub-issues count when > 0', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(subIssuesCount: 5),
          onTap: () {},
        ),
      ));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does not display sub-issues count when 0', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(subIssuesCount: 0),
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
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('does not show overdue icon when not overdue', (tester) async {
      await tester.pumpWidget(wrapWidget(
        IssueRow(
          issue: makeIssue(targetDate: '2099-12-31'),
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.schedule), findsNothing);
    });
  });
}
