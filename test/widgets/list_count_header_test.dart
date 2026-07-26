import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/archive_toggle.dart';
import 'package:plane_mobile/widgets/list_count_header.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ListCountHeader', () {
    test('the sentence is the same one an app bar subtitle would use', () {
      expect(ListCountHeader.label(0, 'cycle'), '0 cycles');
      expect(ListCountHeader.label(1, 'cycle'), '1 cycle');
      expect(ListCountHeader.label(3, 'cycle'), '3 cycles');
      // The nouns that do not just take an "s".
      expect(ListCountHeader.label(2, 'entity', plural: 'entities'),
          '2 entities');
    });

    testWidgets('draws the count', (tester) async {
      await tester.pumpWidget(
          wrap(const ListCountHeader(count: 12, singular: 'module')));
      expect(find.text('12 modules'), findsOneWidget);
    });

    testWidgets('gives a trailing control room for its touch target',
        (tester) async {
      await tester.pumpWidget(wrap(ListCountHeader(
        count: 4,
        singular: 'page',
        trailing: ArchiveToggle(
          showArchived: false,
          entityPlural: 'pages',
          onChanged: (_) {},
        ),
      )));

      // Three screens carried a byte-identical copy of this header, and on all
      // three the archive toggle inside it was about 24dp tall.
      expect(
        tester.getSize(find.byType(ArchiveToggle)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('stays tight when there is nothing beside the count',
        (tester) async {
      await tester.pumpWidget(
          wrap(const ListCountHeader(count: 4, singular: 'page')));
      expect(tester.getSize(find.byType(ListCountHeader)).height, lessThan(48));
    });
  });
}
