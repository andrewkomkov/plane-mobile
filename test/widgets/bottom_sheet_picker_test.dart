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
}
