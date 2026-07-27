import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/widgets/loading_state.dart';
import 'package:plane_mobile/widgets/m3e/loading_indicator.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('LoadingStateWidget', () {
    testWidgets('shows the expressive loading indicator', (tester) async {
      await tester.pumpWidget(wrapWidget(const LoadingStateWidget()));
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      // The indicator animates forever; settle would time out.
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('ErrorStateWidget', () {
    testWidgets('shows default error message', (tester) async {
      await tester.pumpWidget(wrapWidget(const ErrorStateWidget()));
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows custom error message', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const ErrorStateWidget(message: 'Network error'),
      ));
      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('shows error icon', (tester) async {
      await tester.pumpWidget(wrapWidget(const ErrorStateWidget()));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        ErrorStateWidget(onRetry: () {}),
      ));
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const ErrorStateWidget(onRetry: null),
      ));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('fires onRetry callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrapWidget(
        ErrorStateWidget(onRetry: () => retried = true),
      ));

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('shows message', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(message: 'No issues found'),
      ));
      expect(find.text('No issues found'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(
          message: 'Empty',
          icon: Icons.inbox,
        ),
      ));
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('does not show icon when null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(message: 'Empty'),
      ));
      // No icon widgets beyond what MaterialApp provides
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(
          message: 'No issues',
          subtitle: 'Try adjusting filters',
        ),
      ));
      expect(find.text('Try adjusting filters'), findsOneWidget);
    });

    testWidgets('does not show subtitle when null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(message: 'No issues'),
      ));
      expect(find.text('Try adjusting filters'), findsNothing);
    });

    testWidgets('shows the action under the copy', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWidget(
        EmptyStateWidget(
          message: 'No cycles',
          action: FilledButton(
            onPressed: () => tapped = true,
            child: const Text('New cycle'),
          ),
        ),
      ));

      final message = tester.getBottomLeft(find.text('No cycles')).dy;
      expect(
          tester.getTopLeft(find.text('New cycle')).dy, greaterThan(message));

      await tester.tap(find.text('New cycle'));
      expect(tapped, isTrue);
    });

    testWidgets('has no action by default', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const EmptyStateWidget(message: 'No cycles'),
      ));
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('ScrollableEmptyState', () {
    testWidgets('forwards the action to the empty state', (tester) async {
      // The four list screens that wanted a button under their empty state
      // could not use this widget at all before, and hand-rolled the column
      // instead. It has to arrive through here or they go back to doing that.
      await tester.pumpWidget(wrapWidget(
        ScrollableEmptyState(
          message: 'No pages',
          action: FilledButton(
            onPressed: () {},
            child: const Text('New page'),
          ),
        ),
      ));

      expect(find.text('No pages'), findsOneWidget);
      expect(find.text('New page'), findsOneWidget);
    });
  });
}
