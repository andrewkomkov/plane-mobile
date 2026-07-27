import 'package:flutter/material.dart';
import '../config/m3e/shapes.dart';
import '../config/theme.dart';
import 'm3e/loading_indicator.dart';

class CacheIndicator extends StatelessWidget {
  final bool isFromCache;
  final bool isRefreshing;

  const CacheIndicator({
    super.key,
    required this.isFromCache,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFromCache && !isRefreshing) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isRefreshing
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : PlaneTheme.pendingColor(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(M3EShape.extraSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRefreshing) ...[
            M3ELoadingIndicator(
              size: PlaneTheme.iconSmall,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text('Refreshing...',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ] else ...[
            Icon(Icons.cloud_off,
                size: PlaneTheme.iconSmall,
                color: PlaneTheme.pendingColor(context)),
            const SizedBox(width: 6),
            Text('Cached data',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: PlaneTheme.pendingColor(context))),
          ],
        ],
      ),
    );
  }
}
