import 'dart:ui';
import 'package:flutter/material.dart';

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

  // Show "More" only when there are 2+ overflow items (not for just 1)
  bool get _hasMore => items.length > _maxVisible + 1;

  List<NavItem> get _visibleItems =>
      _hasMore ? items.sublist(0, _maxVisible) : items;

  List<NavItem> get _overflowItems =>
      _hasMore ? items.sublist(_maxVisible) : [];

  bool get _isOverflowActive =>
      _hasMore && currentIndex >= _maxVisible;

  Widget _buildGlassPill(BuildContext context, {required Widget child, double? width}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: width,
          height: 56,
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: pillBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 32),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;
    final color = isActive ? accentColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? sheetTheme.colorScheme.surfaceContainer.withValues(alpha: 0.95)
                : sheetTheme.colorScheme.surface.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Navigation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sheetTheme.colorScheme.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close,
                            size: 22,
                            color: sheetTheme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Menu items
                  for (var i = 0; i < _overflowItems.length; i++)
                    _buildOverflowTile(
                      ctx,
                      item: _overflowItems[i],
                      index: _maxVisible + i,
                      onClose: () => Navigator.pop(ctx),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverflowTile(
    BuildContext context, {
    required NavItem item,
    required int index,
    required VoidCallback onClose,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        onClose();
        onTap(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              child: _buildGlassPill(
                context,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      _buildNavItem(
                        context,
                        icon: currentIndex == i
                            ? visible[i].activeIcon
                            : visible[i].icon,
                        label: visible[i].label,
                        isActive: currentIndex == i,
                        onTap: () => onTap(i),
                      ),
                    if (_hasMore)
                      _buildNavItem(
                        context,
                        icon: Icons.menu,
                        label: 'More',
                        isActive: _isOverflowActive,
                        onTap: () => _showMoreSheet(context),
                      ),
                  ],
                ),
              ),
            ),
            if (pendingWrites > 0) ...[
              const SizedBox(width: 8),
              _buildGlassPill(
                context,
                width: 56,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 20,
                        color: const Color(0xFFF59E0B),
                      ),
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$pendingWrites',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (showSearch) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSearchTap,
                onDoubleTap: onSearchDoubleTap,
                onLongPress: onSearchLongPress,
                child: _buildGlassPill(
                  context,
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
            ],
          ],
        ),
      ),
    );
  }
}
