import 'package:flutter/material.dart';
import '../../config/m3e/typography.dart';

/// Material 3 Expressive **flexible app bar**.
///
/// The large title shrinks and slides up into the toolbar row as content
/// scrolls, and a hairline divider fades in only once something is actually
/// scrolled under the bar. M3E made this collapse continuous rather than the
/// two-state snap of M3.
///
/// Packaged as a scaffold rather than a bare app bar because the screens in
/// this app are `Column(header, Expanded(list))` — this drops into that shape
/// directly and picks up scroll position from the body via notifications,
/// instead of forcing every screen to be rewritten as a CustomScrollView.
class M3EFlexibleHeaderScaffold extends StatefulWidget {
  final String title;

  /// Small uppercase line under the title (e.g. "PENDING NOTIFICATIONS").
  final String? overline;

  /// Persistent row below the title — filter chips, button groups.
  final Widget? bottom;

  final List<Widget>? actions;

  /// Leading branding block. Defaults to the workspace mark.
  final Widget? leading;

  final Widget body;

  /// Scroll distance over which the title finishes collapsing.
  final double collapseDistance;

  const M3EFlexibleHeaderScaffold({
    super.key,
    required this.title,
    required this.body,
    this.overline,
    this.bottom,
    this.actions,
    this.leading,
    this.collapseDistance = 72,
  });

  @override
  State<M3EFlexibleHeaderScaffold> createState() =>
      _M3EFlexibleHeaderScaffoldState();
}

class _M3EFlexibleHeaderScaffoldState extends State<M3EFlexibleHeaderScaffold> {
  double _collapse = 0;

  bool _onScroll(ScrollNotification notification) {
    // Only react to the primary vertical list, not to horizontal chip rows or
    // nested scrollables inside list items.
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth > 0) return false;

    final offset = notification.metrics.pixels.clamp(0.0, widget.collapseDistance);
    final next = offset / widget.collapseDistance;
    if ((next - _collapse).abs() > 0.005) {
      setState(() => _collapse = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = _collapse;

    // Title travels from its own large row into the toolbar line.
    final titleSize = lerpDouble(24, 17, t);
    final largeRowHeight = lerpDouble(44, 0, t);
    final largeRowOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
    final inlineOpacity = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Toolbar row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  widget.leading ?? _DefaultLeading(scheme: scheme),
                  const SizedBox(width: 12),
                  // Brand fades out as the collapsed title takes its place.
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Opacity(
                          opacity: 1 - inlineOpacity,
                          child: Text(
                            'Plane',
                            style: TextStyle(
                              fontFamily: M3EType.fontFamily,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: inlineOpacity,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: M3EType.fontFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.actions != null) ...widget.actions!,
                ],
              ),
            ),
          ),

          // ─── Divider: only once content is underneath ───
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AnimatedOpacity(
              opacity: t > 0.02 ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                height: 0.5,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),

          // ─── Large title row, collapsing ───
          ClipRect(
            child: SizedBox(
              height: largeRowHeight,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: 60,
                child: Opacity(
                  opacity: largeRowOpacity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: M3EType.fontFamily,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (widget.overline != null)
            Opacity(
              opacity: largeRowOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                child: Text(
                  widget.overline!,
                  style: M3EType.overline(scheme.onSurfaceVariant)
                      .copyWith(letterSpacing: 1.6),
                ),
              ),
            ),

          if (widget.bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: widget.bottom!,
            ),

          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

class _DefaultLeading extends StatelessWidget {
  final ColorScheme scheme;
  const _DefaultLeading({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Icon(Icons.grid_view, size: 15, color: scheme.primary),
      ),
    );
  }
}
