import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import 'icon_button.dart';

/// Frosted container used by the floating bottom bars.
///
/// M3 Expressive floats its bars off the edge of the screen; Linear frosts
/// them. Both hold here — the blur is the app's identity, the detached pill
/// and full-round corners are M3E's.
class M3EGlassContainer extends StatelessWidget {
  final Widget child;
  final double height;
  final double? width;
  final double blurSigma;

  const M3EGlassContainer({
    super.key,
    required this.child,
    this.height = 60,
    this.width,
    this.blurSigma = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(M3EShape.full);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.86),
            borderRadius: radius,
            border: Border.all(
              // Not outlineVariant: the rim is a specular highlight on glass,
              // so it has to be lighter than the blur behind it, not a fixed
              // scheme colour.
              color: isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class M3EToolbarAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPrimary;

  const M3EToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });
}

/// Material 3 Expressive **floating toolbar**.
///
/// A detached pill of contextual actions that hides when the user scrolls down
/// and springs back when they scroll up, so it never permanently occludes
/// content. Use for per-screen actions (filter, sort, view switch) — global
/// destinations belong in the nav bar.
class M3EFloatingToolbar extends StatelessWidget {
  final List<M3EToolbarAction> actions;

  /// Drives the hide/show. Pass false while scrolling down.
  final bool visible;

  const M3EFloatingToolbar({
    super.key,
    required this.actions,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return M3ESpringBuilder(
      value: visible ? 0 : 1,
      spring: M3EMotion.defaultSpatial,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, t * 110),
        child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
      ),
      child: M3EGlassContainer(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                M3EIconButton(
                  icon: action.icon,
                  tooltip: action.tooltip,
                  onPressed: action.onPressed,
                  style: action.isPrimary
                      ? M3EIconButtonStyle.filled
                      : M3EIconButtonStyle.standard,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
