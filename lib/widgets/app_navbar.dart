import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';
import 'm3e/toolbar.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Bottom navigation, rebuilt on the Material 3 Expressive nav bar.
///
/// M3E's contribution here is the active indicator: a pill that physically
/// travels between destinations on a spatial spring and widens to admit the
/// destination's label, rather than cross-fading a dot. Linear's frosted-glass
/// floating bar is kept as the container — that is the app's signature, and
/// M3E's indicator sits inside it without conflict.
class AppNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSearchDoubleTap;
  final VoidCallback? onSearchLongPress;
  final int pendingWrites;

  static const int _maxVisible = 4;

  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.showSearch = false,
    this.onSearchTap,
    this.onSearchDoubleTap,
    this.onSearchLongPress,
    this.pendingWrites = 0,
  });

  bool get _hasMore => items.length > _maxVisible + 1;

  List<NavItem> get _visibleItems =>
      _hasMore ? items.sublist(0, _maxVisible) : items;

  List<NavItem> get _overflowItems =>
      _hasMore ? items.sublist(_maxVisible) : [];

  bool get _isOverflowActive => _hasMore && currentIndex >= _maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleItems;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: M3EGlassContainer(
                height: 60,
                child: _NavRow(
                  items: visible,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  hasMore: _hasMore,
                  isOverflowActive: _isOverflowActive,
                  onMoreTap: () => _showMoreSheet(context),
                ),
              ),
            ),
            if (pendingWrites > 0) ...[
              const SizedBox(width: 8),
              M3EGlassContainer(
                height: 60,
                width: 56,
                child: Center(child: _PendingBadge(count: pendingWrites)),
              ),
            ],
            if (showSearch) ...[
              const SizedBox(width: 8),
              M3EPressable(
                pressedScale: 0.92,
                onTap: onSearchTap,
                onLongPress: onSearchLongPress,
                semanticLabel: 'Search',
                child: GestureDetector(
                  onDoubleTap: onSearchDoubleTap,
                  child: M3EGlassContainer(
                    height: 60,
                    width: 56,
                    child: Center(
                      child: Icon(
                        Icons.search,
                        size: 22,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(M3EShape.extraLargeIncreased),
            ),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(M3EShape.full),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _overflowItems.length; i++)
                    _OverflowTile(
                      item: _overflowItems[i],
                      isActive: currentIndex == _maxVisible + i,
                      onTap: () {
                        Navigator.pop(ctx);
                        onTap(_maxVisible + i);
                      },
                    ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Nav bar geometry. The indicator travels in a Stack while the icons live in
/// a Row, so both have to derive their vertical placement from the same
/// numbers — otherwise the pill drifts off the icon it is meant to sit behind.
class _NavMetrics {
  const _NavMetrics._();

  static const double barHeight = 60;
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;

  /// Top of the indicator, and therefore of the icon box.
  static const double iconTop = 7;

  /// Gap between the indicator and the label beneath it.
  static const double labelGap = 2;
}

/// The destinations row plus the travelling indicator.
class _NavRow extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasMore;
  final bool isOverflowActive;
  final VoidCallback onMoreTap;

  const _NavRow({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.hasMore,
    required this.isOverflowActive,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slotCount = items.length + (hasMore ? 1 : 0);
    final activeSlot = isOverflowActive ? items.length : currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / slotCount;

        return Stack(
          alignment: Alignment.topLeft,
          children: [
            // Active indicator — springs to the selected slot.
            if (activeSlot >= 0)
              M3ESpringBuilder(
                value: activeSlot.toDouble(),
                spring: M3EMotion.defaultSpatial,
                builder: (context, position, _) {
                  // Pinned to the icon box rather than centred in the bar. The
                  // M3 indicator wraps the ICON only; the label belongs below
                  // it. Centring it on the whole column made both the icon and
                  // a long label like "My Tasks" spill past the pill's edges.
                  return Positioned(
                    top: _NavMetrics.iconTop,
                    left: position * slotWidth +
                        (slotWidth - _NavMetrics.indicatorWidth) / 2,
                    child: Container(
                      width: _NavMetrics.indicatorWidth,
                      height: _NavMetrics.indicatorHeight,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(M3EShape.full),
                      ),
                    ),
                  );
                },
              ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: slotWidth,
                    child: _NavDestination(
                      item: items[i],
                      isActive: currentIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
                if (hasMore)
                  SizedBox(
                    width: slotWidth,
                    child: _NavDestination(
                      item: const NavItem(
                        icon: Icons.more_horiz,
                        activeIcon: Icons.more_horiz,
                        label: 'More',
                      ),
                      isActive: isOverflowActive,
                      onTap: onMoreTap,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NavDestination extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavDestination({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isActive ? scheme.primary : scheme.onSurfaceVariant;

    return M3EPressable(
      pressedScale: 0.88,
      onTap: onTap,
      semanticLabel: item.label,
      selected: isActive,
      child: SizedBox(
        height: _NavMetrics.barHeight,
        child: Column(
          // Top-aligned, not centred: the icon has to land in the same box the
          // indicator is pinned to, and it must not move when the label
          // appears or the icons would jump on every selection change.
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: _NavMetrics.iconTop + _NavMetrics.indicatorHeight,
              child: Center(
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: color,
                ),
              ),
            ),
            // Label appears only for the active destination — M3E's way of
            // keeping the bar quiet while still naming where you are. It sits
            // BELOW the indicator, so it may be wider than the pill.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Easing.emphasizedDecelerate,
              alignment: Alignment.topCenter,
              child: isActive
                  ? Padding(
                      padding:
                          const EdgeInsets.only(top: _NavMetrics.labelGap),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          color: color,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.cloud_upload_outlined, size: 20, color: amber),
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: amber,
              borderRadius: BorderRadius.circular(M3EShape.full),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverflowTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _OverflowTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return M3EPressable(
      pressedScale: 0.97,
      onTap: onTap,
      semanticLabel: item.label,
      selected: isActive,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(M3EShape.large),
          color: isActive
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kept here so callers that only imported this file still resolve the blur.
const double kNavBarBlurSigma = 30;

ImageFilter navBarBlur() =>
    ImageFilter.blur(sigmaX: kNavBarBlurSigma, sigmaY: kNavBarBlurSigma);
