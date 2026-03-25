import 'package:flutter/material.dart';
import '../config/theme.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: PlaneTheme.iconSmall, color: iconColor),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: PlaneTheme.fontCaption,
                    fontWeight: PlaneTheme.fontBodyWeight)),
          ],
        ),
      ),
    );
  }
}
