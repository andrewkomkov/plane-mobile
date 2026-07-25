import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive shape scale.
///
/// M3 Expressive widened the corner scale (the `Increased` steps are new) and
/// made shape an *interactive* property: components change corner radius on
/// press and on selection instead of only changing colour.
class M3EShape {
  const M3EShape._();

  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;

  /// Stadium — expressed as a radius large enough to always clamp.
  static const double full = 999;

  static BorderRadius radius(double corner) => BorderRadius.circular(corner);

  static RoundedRectangleBorder border(double corner) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(corner));

  /// Corner radius a component adopts while pressed. M3E squares things off
  /// slightly under the finger, which reads as the surface taking the load.
  static const double pressedCorner = medium;
}

/// A closed, C¹-smooth "cookie" shape defined in polar coordinates.
///
/// M3 Expressive's shape library is built from rounded polygons that can morph
/// into one another. Rather than porting androidx.graphics.shapes' corner
/// rounding maths, this describes each shape as a lobed radius function, which
/// is smooth by construction and — crucially — morphs by simple interpolation
/// of the sampled radii, with no vertex-matching problem.
@immutable
class M3ECookieShape {
  /// Number of lobes around the perimeter. 0 gives a circle.
  final int lobes;

  /// How far the lobes deviate from the base circle, 0..1.
  final double amplitude;

  /// Rotation in turns, so shapes in a sequence do not all point the same way.
  final double rotation;

  const M3ECookieShape({
    required this.lobes,
    required this.amplitude,
    this.rotation = 0,
  });

  /// The seven-step sequence the expressive loading indicator cycles through.
  static const List<M3ECookieShape> loadingSequence = <M3ECookieShape>[
    M3ECookieShape(lobes: 0, amplitude: 0.0),
    M3ECookieShape(lobes: 4, amplitude: 0.14, rotation: 0.05),
    M3ECookieShape(lobes: 7, amplitude: 0.10, rotation: 0.12),
    M3ECookieShape(lobes: 6, amplitude: 0.16, rotation: 0.20),
    M3ECookieShape(lobes: 9, amplitude: 0.09, rotation: 0.28),
    M3ECookieShape(lobes: 5, amplitude: 0.15, rotation: 0.36),
    M3ECookieShape(lobes: 8, amplitude: 0.11, rotation: 0.44),
  ];

  double _radiusAt(double angle) {
    if (lobes == 0 || amplitude == 0) return 1.0;
    final theta = angle - rotation * 2 * math.pi;
    return 1.0 - amplitude + amplitude * math.cos(lobes * theta);
  }

  static const int _samples = 180;

  /// Builds the outline, scaled to fit [size] and centred in it.
  ///
  /// [morphTo]/[t] blend this shape into another: because both are sampled at
  /// the same angles, blending is a per-sample lerp of the radius.
  Path toPath(Size size, {M3ECookieShape? morphTo, double t = 0}) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / 2;
    final path = Path();

    for (int i = 0; i <= _samples; i++) {
      final angle = (i / _samples) * 2 * math.pi;
      var r = _radiusAt(angle);
      if (morphTo != null && t > 0) {
        r = r + (morphTo._radiusAt(angle) - r) * t;
      }
      final point = Offset(
        center.dx + math.cos(angle) * r * scale,
        center.dy + math.sin(angle) * r * scale,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }
}

/// Clips a child to a [M3ECookieShape], optionally mid-morph.
class M3ECookieClipper extends CustomClipper<Path> {
  final M3ECookieShape shape;
  final M3ECookieShape? morphTo;
  final double t;

  const M3ECookieClipper({required this.shape, this.morphTo, this.t = 0});

  @override
  Path getClip(Size size) => shape.toPath(size, morphTo: morphTo, t: t);

  @override
  bool shouldReclip(M3ECookieClipper old) =>
      old.shape != shape || old.morphTo != morphTo || old.t != t;
}
