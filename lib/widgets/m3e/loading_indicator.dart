import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';

/// Material 3 Expressive **LoadingIndicator**.
///
/// Replaces the spinning arc with a filled shape that rotates while morphing
/// through a sequence of lobed forms. The morph is what carries the sense of
/// progress — a plain rotating circle would look static.
class M3ELoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  /// Contained variant draws the shape on a tonal backdrop, for use inside
  /// buttons and list rows where a bare shape would float.
  final bool contained;

  const M3ELoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.contained = false,
  });

  @override
  State<M3ELoadingIndicator> createState() => _M3ELoadingIndicatorState();
}

class _M3ELoadingIndicatorState extends State<M3ELoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static final List<M3ECookieShape> _sequence = M3ECookieShape.loadingSequence;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: M3EMotion.morphCycle * _sequence.length,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final position = _controller.value * _sequence.length;
          final index = position.floor() % _sequence.length;
          final next = (index + 1) % _sequence.length;
          // Ease the blend so each shape holds briefly before giving way.
          final t = Curves.easeInOutCubic.transform(position - position.floor());

          return CustomPaint(
            painter: _CookiePainter(
              shape: _sequence[index],
              morphTo: _sequence[next],
              t: t,
              rotation: _controller.value * 2 * 3.14159,
              color: color,
              backdrop: widget.contained
                  ? scheme.surfaceContainerHighest
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _CookiePainter extends CustomPainter {
  final M3ECookieShape shape;
  final M3ECookieShape morphTo;
  final double t;
  final double rotation;
  final Color color;
  final Color? backdrop;

  _CookiePainter({
    required this.shape,
    required this.morphTo,
    required this.t,
    required this.rotation,
    required this.color,
    this.backdrop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backdrop != null) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.shortestSide / 2,
        Paint()..color = backdrop!,
      );
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);

    // Inset so the contained backdrop stays visible around the shape.
    final inner = backdrop != null
        ? Size(size.width * 0.62, size.height * 0.62)
        : size;
    canvas.translate((size.width - inner.width) / 2,
        (size.height - inner.height) / 2);

    canvas.drawPath(
      shape.toPath(inner, morphTo: morphTo, t: t),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CookiePainter old) =>
      old.t != t || old.rotation != rotation || old.color != color;
}
