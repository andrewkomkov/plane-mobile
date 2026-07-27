import 'package:flutter/material.dart';
import 'm3e/loading_indicator.dart';

class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: M3ELoadingIndicator(size: 44));
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 40, color: theme.colorScheme.error.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            message ?? 'Something went wrong',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

/// Centres [child] in the viewport and keeps the list pullable.
///
/// Ten screens hand-rolled this as
/// `ListView(children: [SizedBox(height: MediaQuery.height * X), Center(…)])`,
/// with X being 0.2, 0.25 or 0.3 depending on the screen — three different
/// guesses at a number that should not exist. The spacer was never about
/// spacing: [EmptyStateWidget] is already a `Center`, and the height was there
/// to give a `ListView` something tall enough to scroll so that the
/// `RefreshIndicator` around it would still fire.
///
/// A viewport-height constraint says that directly, and
/// `AlwaysScrollableScrollPhysics` says the rest — a short list that cannot
/// scroll cannot be pulled to refresh, which is the same bug nine list screens
/// have in their non-empty branch as well.
class ScrollableCenter extends StatelessWidget {
  final Widget child;

  /// Room under the floating nav bar, where the screen sits behind one.
  final EdgeInsetsGeometry padding;

  const ScrollableCenter({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// [EmptyStateWidget] in the branch of a list screen that has no rows.
///
/// The one call that replaces the spacer-and-`ListView` pattern above. Half the
/// existing call sites pass a guidance [subtitle] and half do not; they should
/// — "No cycles" alone tells a user nothing about whether that is a problem.
class ScrollableEmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  /// The way out of the empty state, where the user has one.
  final Widget? action;

  const ScrollableEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.subtitle,
    this.padding = EdgeInsets.zero,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollableCenter(
      padding: padding,
      child: EmptyStateWidget(
        message: message,
        icon: icon,
        subtitle: subtitle,
        action: action,
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final String? subtitle;

  /// A button under the copy, for the screens where the empty state is
  /// something the user can act on.
  ///
  /// Four list screens wrapped this widget in a `Column` to put a "New …"
  /// button beneath it, which meant four different gaps between the two and a
  /// [ScrollableEmptyState] none of them could use. The gap belongs here.
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 40,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
