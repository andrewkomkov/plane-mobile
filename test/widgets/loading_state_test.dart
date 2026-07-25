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
  });
}
