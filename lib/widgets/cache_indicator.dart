import 'package:flutter/material.dart';
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
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRefreshing) ...[
            M3ELoadingIndicator(
              size: 10,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text('Refreshing...',
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.primary)),
          ] else ...[
            Icon(Icons.cloud_off,
                size: 12, color: Colors.amber[700]),
            const SizedBox(width: 4),
            Text('Cached data',
                style: TextStyle(
                    fontSize: 10, color: Colors.amber[700])),
          ],
        ],
      ),
    );
  }
}
