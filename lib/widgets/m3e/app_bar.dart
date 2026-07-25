import 'package:flutter/material.dart';
import 'icon_button.dart';

/// Material 3 Expressive small top app bar.
///
/// A drop-in replacement for Material's [AppBar] on the project sub-screens,
/// which are `Scaffold(appBar:, body:)` and would need restructuring to use
/// [M3EFlexibleHeaderScaffold]. Implementing [PreferredSizeWidget] keeps that
/// swap to a single line per screen.
///
/// What it changes over stock AppBar: expressive press physics on the leading
/// and action buttons, the M3E title cut, a hairline divider that appears only
/// once content scrolls under it, and no elevation or surface tint ever.
class M3EAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Small line under the title — project identifier, breadcrumb, item count.
  final String? subtitle;

  final List<Widget>? actions;

  /// Overrides the default back button.
  final Widget? leading;

  /// Draws the hairline under the bar. Screens that own a scroll controller
  /// can drive this; the default keeps it always on, matching the old look.
  final bool showDivider;

  /// Optional row pinned below the title — filter chips, a button group.
  final PreferredSizeWidget? bottom;

  final Color? backgroundColor;

  const M3EAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showDivider = true,
    this.bottom,
    this.backgroundColor,
  });

  static const double _barHeight = 56;
  static const double _dividerHeight = 0.5;

  // The divider is a child of the same Column, so it has to be counted here —
  // Scaffold hands the bar exactly preferredSize.height and anything unbudgeted
  // overflows.
  @override
  Size get preferredSize => Size.fromHeight(
        _barHeight +
            (bottom?.preferredSize.height ?? 0) +
            (showDivider ? _dividerHeight : 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPop = Navigator.of(context).canPop();

    return Material(
      color: backgroundColor ?? theme.scaffoldBackgroundColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _barHeight,
              child: Padding(
                // 4 either side, so the 48dp action circles sit the same
                // distance from both screen edges.
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (leading != null)
                      leading!
                    else if (canPop)
                      M3EAppBarAction(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                      )
                    else
                      const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: canPop || leading != null ? 4 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
            if (bottom != null) bottom!,
            if (showDivider)
              Container(
                height: _dividerHeight,
                color: scheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon button for [M3EAppBar] rows.
///
/// Kept as a named type because fifteen screens spell their actions this way,
/// but it is only a naming of intent now — the drawing is [M3EIconButton], so
/// an app bar action is the same circle, at the same diameter, as every other
/// icon-only control in the app.
class M3EAppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  /// Draws the action as a filled tonal circle — for the one primary action.
  final bool emphasized;

  const M3EAppBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return M3EIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      color: color,
      style: emphasized
          ? M3EIconButtonStyle.filled
          : M3EIconButtonStyle.standard,
    );
  }
}
