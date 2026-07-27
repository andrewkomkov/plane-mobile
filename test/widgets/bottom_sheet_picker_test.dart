import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/widgets/bottom_sheet_picker.dart';
import 'package:plane_mobile/widgets/confirm_dialog.dart';
import 'package:plane_mobile/widgets/sheet_header.dart';

void main() {
  /// Opens [open] from a button, so the sheet or dialog gets a real route.
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: PlaneTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('BottomSheetPicker', () {
    testWidgets('shows a header and every option', (tester) async {
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Priority',
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      expect(find.byType(SheetHeader), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('returns the chosen value', (tester) async {
      String? chosen;
      await pumpOpener(tester, (context) async {
        chosen = await BottomSheetPicker.show<String>(
          context: context,
          title: 'Priority',
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      await tester.tap(find.text('Low'));
      await tester.pumpAndSettle();
      expect(chosen, 'low');
    });

    testWidgets('marks the current value, and only it', (tester) async {
      // The hand-rolled sheets disagreed about this more than anything else:
      // the same two pickers show a check on one screen and nothing at all on
      // another.
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Priority',
          selectedValue: 'low',
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('selection is not carried by the check alone', (tester) async {
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Priority',
          selectedValue: 'low',
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      BoxDecoration decorationFor(String label) => tester
          .widget<Container>(find.ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          ))
          .decoration! as BoxDecoration;

      final selected = decorationFor('Low');
      final unselected = decorationFor('Urgent');
      expect(selected.color, isNot(unselected.color),
          reason: 'the selected row steps the surface');
      expect(selected.borderRadius, isNot(unselected.borderRadius),
          reason: 'and pulls its corner in, the same way M3EChip does');
    });

    testWidgets('every row is at least 48dp and names itself', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<int>(
          context: context,
          title: 'Role',
          items: const [
            BottomSheetPickerItem(
                value: 15, label: 'Member', subtitle: 'Can edit work items'),
          ],
        );
      });

      expect(tester.getSize(find.text('Member')).height, lessThan(48));
      final row = find.ancestor(
        of: find.text('Member'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));

      // M3EPressable replaces the subtree's semantics, so the subtitle only
      // reaches a screen reader if the row's own label carries it.
      expect(find.bySemanticsLabel('Member, Can edit work items'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('an action sheet has no selection to show', (tester) async {
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Jane Doe',
          items: const [
            BottomSheetPickerItem(
                value: 'remove',
                label: 'Remove from project',
                icon: Icons.person_remove_outlined,
                destructive: true),
          ],
        );
      });

      expect(find.byIcon(Icons.check), findsNothing);
      final label = tester.widget<Text>(find.text('Remove from project'));
      expect(label.style?.color, PlaneTheme.dark().colorScheme.error);
    });

    testWidgets('a long list scrolls instead of overflowing', (tester) async {
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<int>(
          context: context,
          title: 'Project',
          items: [
            for (int i = 0; i < 40; i++)
              BottomSheetPickerItem(value: i, label: 'Project $i'),
          ],
        );
      });

      // No overflow exception, and the tail is reachable.
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('Project 39'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Project 39'), findsOneWidget);
    });
  });

  group('confirmDestructive', () {
    testWidgets('the dangerous button is the one in the error role',
        (tester) async {
      await pumpOpener(tester, (context) async {
        await confirmDestructive(
          context,
          title: 'Delete page',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
        );
      });

      final scheme = PlaneTheme.dark().colorScheme;
      final confirm = tester.widget<TextButton>(find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(TextButton),
      ));
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        scheme.error,
        reason: 'seven irreversible actions in this app currently render '
            'identically to Cancel',
      );

      final cancel = tester.widget<TextButton>(find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(TextButton),
      ));
      expect(cancel.style?.foregroundColor, isNull);
    });

    testWidgets('confirming resolves true, cancelling false', (tester) async {
      bool? result;
      await pumpOpener(tester, (context) async {
        result = await confirmDestructive(
          context,
          title: 'Delete page',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
        );
      });

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('a dismissed dialog is not a confirmation', (tester) async {
      bool? result;
      await pumpOpener(tester, (context) async {
        result = await confirmDestructive(
          context,
          title: 'Delete page',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
        );
      });

      Navigator.of(tester.element(find.text('Delete'))).pop();
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('MultiSelectSheet', () {
    testWidgets('takes more than one answer and returns the set',
        (tester) async {
      Set<String>? chosen;
      await pumpOpener(tester, (context) async {
        chosen = await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Priority',
          selected: const {'urgent'},
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      expect(find.byType(SheetHeader), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Low'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(chosen, {'urgent', 'low'});
    });

    testWidgets('tapping a chosen row unchooses it', (tester) async {
      Set<String>? chosen;
      await pumpOpener(tester, (context) async {
        chosen = await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Priority',
          selected: const {'urgent'},
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
          ],
        );
      });

      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
    });

    testWidgets('every row shows a box, chosen or not', (tester) async {
      // The single-choice sheet shows nothing on an unchosen row. Here an
      // empty box is the only thing that says several answers are allowed.
      await pumpOpener(tester, (context) async {
        await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Priority',
          selected: const {'urgent'},
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
            BottomSheetPickerItem(value: 'low', label: 'Low'),
          ],
        );
      });

      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('Clear appears only when something is chosen, and clears',
        (tester) async {
      await pumpOpener(tester, (context) async {
        await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Priority',
          selected: const {},
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
          ],
        );
      });

      expect(find.text('Clear'), findsNothing);

      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear'), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNothing);
    });

    testWidgets('a dismissed sheet discards the changes', (tester) async {
      Set<String>? chosen = {'sentinel'};
      await pumpOpener(tester, (context) async {
        chosen = await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Priority',
          selected: const {'urgent'},
          items: const [
            BottomSheetPickerItem(value: 'urgent', label: 'Urgent'),
          ],
        );
      });

      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Urgent'))).pop();
      await tester.pumpAndSettle();
      expect(chosen, isNull);
    });

    testWidgets('says so when there is nothing to choose from',
        (tester) async {
      await pumpOpener(tester, (context) async {
        await MultiSelectSheet.show<String>(
          context: context,
          title: 'Filter by Label',
          selected: const {},
          items: const [],
          emptyMessage: 'No labels',
        );
      });

      expect(find.text('No labels'), findsOneWidget);
    });
  });

  group('BottomSheetPickerItem.enabled', () {
    testWidgets('a row the server would refuse does not answer a tap',
        (tester) async {
      String? chosen = 'untouched';
      await pumpOpener(tester, (context) async {
        chosen = await BottomSheetPicker.show<String>(
          context: context,
          title: 'Work item',
          items: const [
            BottomSheetPickerItem(
              value: 'archive',
              label: 'Archive work item',
              enabled: false,
              subtitle: 'Only completed or cancelled work items',
            ),
          ],
        );
      });

      await tester.tap(find.text('Archive work item'));
      await tester.pumpAndSettle();
      // Still open, still nothing chosen.
      expect(find.text('Archive work item'), findsOneWidget);
      expect(chosen, 'untouched');
    });

    testWidgets('and dims its label, not only its icon', (tester) async {
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Work item',
          items: const [
            BottomSheetPickerItem(
                value: 'a', label: 'Archive work item', enabled: false),
            BottomSheetPickerItem(value: 'd', label: 'Delete work item'),
          ],
        );
      });

      Color colourOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      expect(colourOf('Archive work item').a,
          lessThan(colourOf('Delete work item').a));
    });

    testWidgets('and says as much to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOpener(tester, (context) async {
        await BottomSheetPicker.show<String>(
          context: context,
          title: 'Work item',
          items: const [
            BottomSheetPickerItem(
              value: 'archive',
              label: 'Archive work item',
              enabled: false,
              subtitle: 'Only completed or cancelled work items',
            ),
          ],
        );
      });

      expect(
        find.bySemanticsLabel('Archive work item, unavailable, '
            'Only completed or cancelled work items'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('MultiSelectSheet as an adder', () {
    testWidgets('counts what it will add and refuses to add nothing',
        (tester) async {
      Set<String>? chosen;
      await pumpOpener(tester, (context) async {
        chosen = await MultiSelectSheet.show<String>(
          context: context,
          title: 'Add issues',
          selected: const {},
          confirmLabel: 'Add',
          showCount: true,
          requireSelection: true,
          items: const [
            BottomSheetPickerItem(value: 'i1', label: 'First issue'),
            BottomSheetPickerItem(value: 'i2', label: 'Second issue'),
          ],
        );
      });

      expect(find.text('Add (0)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'adding nothing is not an action',
      );

      await tester.tap(find.text('First issue'));
      await tester.pumpAndSettle();
      expect(find.text('Add (1)'), findsOneWidget);

      await tester.tap(find.text('Add (1)'));
      await tester.pumpAndSettle();
      expect(chosen, {'i1'});
    });

    testWidgets('the create row leaves without applying a part-made choice',
        (tester) async {
      var created = false;
      Set<String>? chosen = {'sentinel'};
      await pumpOpener(tester, (context) async {
        chosen = await MultiSelectSheet.show<String>(
          context: context,
          title: 'Labels',
          selected: const {},
          createLabel: 'Create new label',
          onCreate: () => created = true,
          items: const [
            BottomSheetPickerItem(value: 'l1', label: 'Bug'),
          ],
        );
      });

      await tester.tap(find.text('Bug'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new label'));
      await tester.pumpAndSettle();

      expect(created, isTrue);
      expect(chosen, isNull, reason: 'a discard, so the caller applies nothing');
    });
  });
}
