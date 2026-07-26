import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/reaction.dart';
import 'package:plane_mobile/widgets/reaction_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  ReactionGroup reaction({bool mine = false}) => ReactionGroup(
        reaction: '128077',
        emoji: '👍',
        count: 1,
        reactedByMe: mine,
      );

  group('ReactionBar', () {
    testWidgets('an empty bar names its own affordance', (tester) async {
      // On the work item this control was an outlined circle alone in a band
      // of whitespace: nothing on screen said what it did until it had been
      // tapped once, and with no chips beside it there was no context to
      // infer from either.
      await tester.pumpWidget(wrap(ReactionBar(
        groups: const [],
        onToggle: (_) {},
        targetDescription: 'this work item',
      )));

      expect(find.text('React'), findsOneWidget);
    });

    testWidgets('a bar with reactions in it goes back to the icon',
        (tester) async {
      // Once chips are there the row explains itself, and repeating the word
      // beside every emoji is noise.
      await tester.pumpWidget(wrap(ReactionBar(
        groups: [reaction()],
        onToggle: (_) {},
        targetDescription: 'this work item',
      )));

      expect(find.text('React'), findsNothing);
      expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);
    });

    testWidgets('comment bars stay compact even when empty', (tester) async {
      // One of these sits on every card in the activity feed.
      await tester.pumpWidget(wrap(ReactionBar(
        groups: const [],
        onToggle: (_) {},
        targetDescription: 'comment by Ada',
        compact: true,
      )));

      expect(find.text('React'), findsNothing);
    });

    testWidgets('both forms of the add button keep their name and action',
        (tester) async {
      // tool/adb_drive.py addresses controls by label, and the label has to
      // name which bar it belongs to — several sit on one screen. The tap
      // action matters as much: the node excludes its subtree, which drops
      // the gesture's own action unless it is re-declared.
      final handle = tester.ensureSemantics();

      for (final groups in [
        <ReactionGroup>[],
        [reaction()]
      ]) {
        await tester.pumpWidget(wrap(ReactionBar(
          groups: groups,
          onToggle: (_) {},
          targetDescription: 'this work item',
        )));

        expect(
          tester.getSemantics(
              find.bySemanticsLabel('Add reaction to this work item')),
          isSemantics(
            label: 'Add reaction to this work item',
            isButton: true,
            hasTapAction: true,
          ),
        );
      }

      handle.dispose();
    });

    testWidgets('a reaction chip says who reacted and can be activated',
        (tester) async {
      final handle = tester.ensureSemantics();
      var toggled = '';

      await tester.pumpWidget(wrap(ReactionBar(
        groups: [reaction(mine: true)],
        onToggle: (code) => toggled = code,
        targetDescription: 'this work item',
      )));

      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('thumbs up'))),
        isSemantics(
          label: 'thumbs up, reacted by you. Tap to remove your reaction',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.bySemanticsLabel(RegExp('thumbs up')));
      expect(toggled, '128077');

      handle.dispose();
    });

    testWidgets('the add button keeps a 48dp target in both forms',
        (tester) async {
      // The named pill only pads its height out; the circle has to be padded
      // in both axes or the target shrinks to the 28dp ring drawn inside it.
      await tester.pumpWidget(wrap(ReactionBar(
        groups: [reaction()],
        onToggle: (_) {},
        targetDescription: 'this work item',
      )));
      final ring = tester.getRect(find.byIcon(Icons.add_reaction_outlined));
      final circleTarget = tester.getRect(find
          .ancestor(
            of: find.byIcon(Icons.add_reaction_outlined),
            matching: find.byType(SizedBox),
          )
          .first);
      expect(circleTarget.width, closeTo(48, 0.01));
      expect(circleTarget.height, closeTo(48, 0.01));
      expect(ring.width, lessThan(48));

      await tester.pumpWidget(wrap(ReactionBar(
        groups: const [],
        onToggle: (_) {},
        targetDescription: 'this work item',
      )));
      final pillTarget = tester.getRect(find
          .ancestor(
            of: find.text('React'),
            matching: find.byType(SizedBox),
          )
          .last);
      expect(pillTarget.height, closeTo(48, 0.01));
      expect(pillTarget.width, lessThan(200),
          reason: 'the pill sizes to its own text, not to the Wrap');
    });
  });
}
