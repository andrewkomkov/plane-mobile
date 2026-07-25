import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';

class M3EMenuOption {
  final String label;
  final IconData? icon;
  final VoidCallback onSelected;
  final bool isDestructive;

  const M3EMenuOption({
    required this.label,
    this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });
}

/// Material 3 Expressive **SplitButton**.
///
/// One primary action plus a trailing chevron that reveals related actions.
/// The trailing half is a real toggle: while the menu is open its chevron flips
/// and its inner corner rounds out, so the button itself shows menu state
/// instead of leaving that job entirely to the popup.
class M3ESplitButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final List<M3EMenuOption> options;

  /// Filled uses primaryContainer; tonal uses a neutral surface. Linear leans
  /// heavily on tonal, so that is the default here.
  final bool filled;
  final double height;

  const M3ESplitButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    required this.options,
    this.filled = false,
    this.height = 40,
  });

  @override
  State<M3ESplitButton> createState() => _M3ESplitButtonState();
}

class _M3ESplitButtonState extends State<M3ESplitButton> {
  bool _open = false;

  Future<void> _showMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 4,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );

    setState(() => _open = true);
    final theme = Theme.of(context);

    final selected = await showMenu<M3EMenuOption>(
      context: context,
      position: position,
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3EShape.large),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      items: [
        for (final option in widget.options)
          PopupMenuItem<M3EMenuOption>(
            value: option,
            height: 44,
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 18,
                    color: option.isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  option.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: option.isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (mounted) setState(() => _open = false);
    selected?.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        widget.filled ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground =
        widget.filled ? scheme.onPrimaryContainer : scheme.onSurface;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Leading — the primary action.
          M3EPressable(
            pressedScale: 0.94,
            onTap: widget.onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(M3EShape.full),
                  bottomLeft: Radius.circular(M3EShape.full),
                  topRight: Radius.circular(M3EShape.small),
                  bottomRight: Radius.circular(M3EShape.small),
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: M3EType.emphasized(
                      Theme.of(context).textTheme.labelLarge!,
                    ).copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Trailing — the menu toggle.
          M3EPressable(
            pressedScale: 0.94,
            onTap: _showMenu,
            child: M3ESpringBuilder(
              value: _open ? 1 : 0,
              spring: M3EMotion.defaultSpatial,
              builder: (context, t, _) => Container(
                width: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                        M3EShape.small + (M3EShape.large - M3EShape.small) * t),
                    bottomLeft: Radius.circular(
                        M3EShape.small + (M3EShape.large - M3EShape.small) * t),
                    topRight: const Radius.circular(M3EShape.full),
                    bottomRight: const Radius.circular(M3EShape.full),
                  ),
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: t * 3.14159,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
