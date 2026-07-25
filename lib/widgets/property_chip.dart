import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';

/// Read-only property display (state, priority, assignee, due date).
///
/// Distinct from [M3EChip]: the icon keeps its own semantic colour — priority
/// red, state green — while the label stays neutral, so a row of these reads as
/// data rather than as a row of selectable filters.
class PropertyChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const PropertyChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return M3EPressable(
      pressedScale: onTap == null ? 1.0 : 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(M3EShape.small),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
