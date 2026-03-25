import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/group_header.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('GroupHeader', () {
    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const GroupHeader(
          label: 'In Progress',
          count: 3,
          color: Colors.amber,
        ),
      ));

      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('displays count', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const GroupHeader(
          label: 'Backlog',
          count: 12,
          color: Colors.grey,
        ),
      ));

      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('displays zero count', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const GroupHeader(
          label: 'Done',
          count: 0,
          color: Colors.green,
        ),
      ));

      expect(find.text('0'), findsOneWidget);
    });
  });
}
