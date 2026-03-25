import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Universal section/group header used across all list screens.
/// Matches mockup: uppercase label + count badge pill.
class SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final Color? color;

  const SectionHeader({
    super.key,
    required this.label,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 24, 20, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: PlaneTheme.fontSection,
              fontWeight: PlaneTheme.fontSectionWeight,
              letterSpacing: 0.65,
              color: effectiveColor,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: PlaneTheme.fontSmall,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
