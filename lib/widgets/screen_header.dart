import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Universal screen header used by all top-level tabs.
/// Provides a top bar with avatar + "Plane" branding, then title + actions below.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitleText;
  final List<Widget>? actions;
  final Widget? subtitle;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitleText,
    this.actions,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar: avatar + Plane + right icons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.20),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.grid_view, size: 16, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Plane',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        // Thin divider
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            height: 0.5,
            color: theme.colorScheme.outline.withValues(alpha: 0.30),
          ),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: PlaneTheme.fontTitle,
              fontWeight: PlaneTheme.fontTitleWeight,
              letterSpacing: -0.3,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        // Subtitle text (like "PENDING NOTIFICATIONS")
        if (subtitleText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              subtitleText!,
              style: TextStyle(
                fontSize: PlaneTheme.fontSection,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        // Custom subtitle widget (like filter pills)
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: subtitle!,
          ),
      ],
    );
  }
}
