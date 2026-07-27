import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/draft_issue.dart';
import 'package:plane_mobile/screens/issues/issue_create_screen.dart';

import '../test_helpers.dart';

/// The compose form, in both of the modes it now serves.
///
/// Nothing here touches the network: every assertion is about what the screen
/// shows before a write, or about a guard that refuses to make one.
void main() {
  final states = {'state-1': makeState(id: 'state-1', name: 'Todo')};

  DraftIssue draft(Map<String, dynamic> overrides) => DraftIssue.fromJson({
        'id': 'draft-1',
        'name': 'Half a thought',
        'project_id': 'proj-1',
        'priority': 'high',
        ...overrides,
      });

  Widget wrap({DraftIssue? draft, String? parentIssueId}) => MaterialApp(
        home: IssueCreateScreen(
          workspaceSlug: 'ws',
          projectId: 'proj-1',
          states: states,
          parentIssueId: parentIssueId,
          draft: draft,
        ),
      );

  group('composing a new work item', () {
    testWidgets('offers saving as a draft alongside creating', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());

      expect(find.text('New Issue'), findsOneWidget);
      expect(find.bySemanticsLabel('Save as draft'), findsOneWidget);
      expect(find.bySemanticsLabel('Create work item'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('has nothing to discard', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Discard draft'), findsNothing);
    });

    testWidgets('still says sub-issue when it is one', (tester) async {
      await tester.pumpWidget(wrap(parentIssueId: 'issue-7'));
      expect(find.text('New Sub-issue'), findsOneWidget);
    });

    testWidgets('refuses an untitled work item instead of letting it 400',
        (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('Create'));
      await tester.pump();

      expect(find.text('A work item needs a title'), findsOneWidget);
    });
  });

  group('the rest of a work item', () {
    /// A viewport tall enough for the whole form.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('offers assignees, labels and both dates', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The form carried title, description, status and priority and nothing
      // else, so a draft written on the web showed its assignees here and lost
      // them on save.
      expect(find.text('ASSIGNEES'), findsOneWidget);
      expect(find.text('LABELS'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(find.text('DUE'), findsOneWidget);
    });

    testWidgets('says plainly when nothing is chosen', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Unassigned'), findsOneWidget);
      // Labels, and both dates.
      expect(find.text('None'), findsNWidgets(3));
    });

    testWidgets('a draft opens with its assignees, labels and dates',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(
        draft: draft({
          'assignee_ids': ['user-1', 'user-2'],
          'label_ids': ['label-1'],
          'start_date': '2026-03-01',
          'target_date': '2026-03-14',
        }),
      ));
      await tester.pumpAndSettle();

      // Counted rather than named: the member and label lists cannot be
      // fetched here, and a field that renders a raw id would be worse than
      // one that renders a count.
      expect(find.text('2 people'), findsOneWidget);
      expect(find.text('1 label'), findsOneWidget);
      expect(find.text('1/3/2026'), findsOneWidget);
      expect(find.text('14/3/2026'), findsOneWidget);
    });

    testWidgets('no cycle or module field where the project has neither',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Plane's per-project feature flags can turn both off, and a picker
      // with nothing behind it answers a tap with an empty sheet.
      expect(find.text('CYCLE'), findsNothing);
      expect(find.text('MODULES'), findsNothing);
    });
  });

  group('editing a draft', () {
    testWidgets('is the same form, prefilled', (tester) async {
      await tester.pumpWidget(wrap(
        draft: draft({'description_html': '<p>some notes</p>'}),
      ));

      expect(find.text('Edit draft'), findsOneWidget);
      expect(find.text('Half a thought'), findsOneWidget);
      expect(find.text('some notes'), findsOneWidget);
      // The draft's own priority, not the form's default of medium.
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('flattens block markup into lines rather than dropping it',
        (tester) async {
      await tester.pumpWidget(wrap(
        draft: draft({'description_html': '<p>first</p><p>second</p>'}),
      ));

      expect(find.text('first\nsecond'), findsOneWidget);
    });

    testWidgets('decodes entities so the text is not read as markup',
        (tester) async {
      await tester.pumpWidget(wrap(
        draft: draft({'description_html': '<p>Tom &amp; Jerry</p>'}),
      ));

      expect(find.text('Tom & Jerry'), findsOneWidget);
    });

    testWidgets('warns before it costs a web draft its formatting',
        (tester) async {
      // The alternative was refusing to open a rich draft, which would leave
      // it exactly as unreachable as it was before any of this existed.
      await tester.pumpWidget(wrap(
        draft: draft({'description_html': '<p><strong>bold</strong></p>'}),
      ));

      expect(find.textContaining('drops the formatting'), findsOneWidget);
    });

    testWidgets('stays quiet about formatting a plain draft does not have',
        (tester) async {
      await tester.pumpWidget(wrap(
        draft: draft({'description_html': '<p>plain</p>'}),
      ));

      expect(find.textContaining('drops the formatting'), findsNothing);
    });

    testWidgets('keeps the same two words for the same two outcomes',
        (tester) async {
      // "Create" ends with a work item and "Save draft" ends with a draft, in
      // both modes and in the same order — the only thing that changes is what
      // they are acting on, which is what the announced names say.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(draft: draft({})));

      expect(find.text('Save draft'), findsWidgets);
      expect(find.text('Create'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Create work item from draft'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('puts discarding at the far end of the form', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(draft: draft({})));

      final discard = find.bySemanticsLabel('Discard draft');
      expect(discard, findsOneWidget);
      // Below the two buttons that save, not beside them.
      expect(
        tester.getCenter(discard).dy,
        greaterThan(tester.getCenter(find.text('Create')).dy),
      );
      handle.dispose();
    });

    testWidgets('asks before discarding, and says it is final', (tester) async {
      // The form carries every field a work item has, which is taller than the
      // default 800x600 test surface — and a control below the fold cannot be
      // tapped.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(draft: draft({})));

      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();

      expect(find.text('Discard draft?'), findsOneWidget);
      expect(find.textContaining('no way to bring it back'), findsOneWidget);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('Discard draft?'), findsNothing);
    });

    testWidgets('will not promote a draft the server would refuse',
        (tester) async {
      // `create_draft_to_issue` returns 400 for a project-less draft. Saying so
      // is better than a snackbar full of Dio.
      await tester.pumpWidget(wrap(draft: draft({'project_id': null})));

      await tester.tap(find.text('Create'));
      await tester.pump();

      expect(
        find.text('This draft has no project and cannot become a work item'),
        findsOneWidget,
      );
    });

    testWidgets('an unnamed draft opens with an empty field, not a stand-in',
        (tester) async {
      // The list titles a nameless draft "Untitled draft" so the row is
      // readable; prefilling that here would save it as the draft's real name.
      await tester.pumpWidget(wrap(draft: draft({'name': null})));

      expect(find.text(DraftIssue.untitled), findsNothing);
    });
  });
}
