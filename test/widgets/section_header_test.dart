import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/section_header.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('SectionHeader', () {
    testWidgets('puts the trailing control at the end of the row',
        (tester) async {
      await tester.pumpWidget(wrap(SectionHeader(
        label: 'Members',
        count: 3,
        trailing: IconButton(
          icon: const Icon(Icons.person_add_alt),
          onPressed: () {},
        ),
      )));

      final label = tester.getTopRight(find.text('MEMBERS')).dx;
      final control = tester.getTopLeft(find.byType(IconButton)).dx;
      expect(control, greaterThan(label));
      // Inside the header's own right inset, not flush with the screen edge.
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(tester.getTopRight(find.byType(IconButton)).dx,
          lessThan(screenWidth));
    });

    testWidgets('leaves the label the width the control does not take',
        (tester) async {
      // A Flexible label beside a Spacer would ellipsize at half the header
      // however narrow the control is. This label fits in the space a 40dp
      // button leaves, so it must not be truncated.
      const label = 'A section heading of some length';
      await tester.pumpWidget(wrap(SectionHeader(
        label: label,
        trailing: IconButton(icon: const Icon(Icons.add), onPressed: () {}),
      )));

      final text = tester.widget<Text>(find.text(label.toUpperCase()));
      final painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(tester.getSize(find.text(label.toUpperCase())).width,
          closeTo(painter.width, 1));
    });

    testWidgets('renders label and count unchanged without a trailing',
        (tester) async {
      await tester.pumpWidget(wrap(
        const SectionHeader(label: 'Archive', count: 12),
      ));

      expect(find.text('ARCHIVE'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
