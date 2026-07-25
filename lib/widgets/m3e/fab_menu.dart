import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';

class M3EFabAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const M3EFabAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Material 3 Expressive **FAB Menu**.
///
/// Tapping the FAB expands it into a column of labelled actions that spring in
/// bottom-up with a stagger, over a blurred scrim, while the FAB's own icon
/// morphs to a close affordance. This replaces the speed-dial pattern: the
/// actions carry text labels, so the menu is readable without guessing icons.
///
/// Rendered through an [OverlayEntry] so the expanded menu is never clipped by
/// whatever bounded box the FAB happens to sit in.
class M3EFabMenu extends StatefulWidget {
  final List<M3EFabAction> actions;

  /// Shown on the collapsed FAB.
  final IconData icon;

  /// When set, the FAB is extended and shows this text next to the icon.
  final String? label;

  const M3EFabMenu({
    super.key,
    required this.actions,
    this.icon = Icons.add,
    this.label,
  });

  @override
  State<M3EFabMenu> createState() => _M3EFabMenuState();
}

class _M3EFabMenuState extends State<M3EFabMenu>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _entry?.remove();
    _controller.dispose();
    super.dispose();
  }

  bool get _isOpen => _entry != null;

  void _open() {
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final fabSize = box.size;
    final theme = Theme.of(context);

    _entry = OverlayEntry(
      builder: (context) => _FabMenuOverlay(
        animation: _controller,
        actions: widget.actions,
        fabOrigin: origin,
        fabSize: fabSize,
        overlaySize: overlayBox.size,
        theme: theme,
        collapsedIcon: widget.icon,
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_entry!);
    setState(() {});
    _controller.forward();
  }

  Future<void> _close() async {
    await _controller.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return M3EPressable(
      pressedScale: 0.92,
      onTap: () => _isOpen ? _close() : _open(),
      semanticLabel: widget.label ?? 'Actions',
      selected: _isOpen,
      child: M3ESpringBuilder(
        value: _isOpen ? 1 : 0,
        spring: M3EMotion.defaultSpatial,
        builder: (context, t, _) {
          return Container(
            height: 56,
            padding: EdgeInsets.symmetric(
              horizontal: widget.label != null ? 20 : 16,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              // Shape morphs toward a circle as the menu opens — the FAB is
              // becoming a dismiss target, and shape says so before colour can.
              borderRadius: BorderRadius.circular(
                M3EShape.large + (M3EShape.extraLarge - M3EShape.large) * t,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: t * 0.785398, // 45° — plus turns into a close glyph
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (widget.label != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FabMenuOverlay extends StatelessWidget {
  final Animation<double> animation;
  final List<M3EFabAction> actions;
  final Offset fabOrigin;
  final Size fabSize;
  final Size overlaySize;
  final ThemeData theme;
  final IconData collapsedIcon;
  final VoidCallback onDismiss;

  const _FabMenuOverlay({
    required this.animation,
    required this.actions,
    required this.fabOrigin,
    required this.fabSize,
    required this.overlaySize,
    required this.theme,
    required this.collapsedIcon,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    const itemHeight = 52.0;
    const itemGap = 8.0;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        return Stack(
          children: [
            // Scrim — blur rather than a flat dim, so the list underneath stays
            // legible as context while clearly receding.
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12 * t, sigmaY: 12 * t),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45 * t),
                  ),
                ),
              ),
            ),
            // Actions, stacked upward from the FAB.
            for (int i = 0; i < actions.length; i++)
              _buildAction(
                context,
                index: i,
                total: actions.length,
                t: t,
                itemHeight: itemHeight,
                itemGap: itemGap,
                scheme: scheme,
              ),
          ],
        );
      },
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required int index,
    required int total,
    required double t,
    required double itemHeight,
    required double itemGap,
    required ColorScheme scheme,
  }) {
    // The bottom-most item leads; each one above it starts slightly later.
    final reverseIndex = total - 1 - index;
    final delay = reverseIndex * 0.08;
    final progress = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(progress);

    final stackOffset = (total - index) * (itemHeight + itemGap);
    final bottom = overlaySize.height - fabOrigin.dy - fabSize.height;

    final action = actions[index];

    return Positioned(
      right: overlaySize.width - fabOrigin.dx - fabSize.width,
      bottom: bottom + fabSize.height + stackOffset * eased - itemHeight,
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.8 + 0.2 * eased,
          alignment: Alignment.bottomRight,
          child: M3EPressable(
            pressedScale: 0.94,
            onTap: () {
              onDismiss();
              action.onPressed();
            },
            child: Container(
              height: itemHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(M3EShape.full),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 20, color: scheme.onSurface),
                  const SizedBox(width: 12),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
