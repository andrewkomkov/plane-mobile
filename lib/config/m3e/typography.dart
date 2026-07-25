import 'package:flutter/material.dart';

/// Material 3 Expressive type scale, tuned for Linear's density.
///
/// M3 Expressive's typographic contribution is *emphasis*: each role gains a
/// heavier "emphasized" cut used to mark the one thing on screen that matters,
/// instead of relying on colour alone. The sizes here stay close to Linear's
/// compact scale rather than stock M3 — Linear runs roughly two steps tighter
/// than Material's defaults, and inflating them would lose the product's
/// character even though the roles are M3E's.
class M3EType {
  const M3EType._();

  static const String fontFamily = 'Inter';

  // Weight tokens. The "emphasized" roles below step up exactly one notch,
  // which is what makes emphasis read as deliberate rather than random.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    TextStyle base(
      double size,
      FontWeight weight, {
      double? spacing,
      double? height,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: height,
          color: color ?? onSurface,
        );

    return TextTheme(
      // Display — only the collapsed/expanded large app bar uses these.
      displayLarge: base(40, bold, spacing: -1.0, height: 1.1),
      displayMedium: base(34, bold, spacing: -0.8, height: 1.12),
      displaySmall: base(30, bold, spacing: -0.6, height: 1.15),

      // Headline — screen titles.
      headlineLarge: base(28, bold, spacing: -0.5, height: 1.18),
      headlineMedium: base(24, bold, spacing: -0.4, height: 1.2),
      headlineSmall: base(20, semiBold, spacing: -0.3, height: 1.25),

      // Title — sheet headers, section titles, list item titles.
      titleLarge: base(18, semiBold, spacing: -0.2, height: 1.3),
      titleMedium: base(15, medium, spacing: -0.1, height: 1.35),
      titleSmall: base(13, medium, height: 1.4),

      // Body — descriptions, comments, markdown.
      bodyLarge: base(15, regular, height: 1.45),
      bodyMedium: base(14, regular, height: 1.45, color: onSurface),
      bodySmall: base(12, regular, height: 1.4, color: onSurfaceVariant),

      // Label — buttons, chips, badges, overline group headers.
      labelLarge: base(14, medium, spacing: 0.1),
      labelMedium: base(12, medium, spacing: 0.2),
      labelSmall: base(11, medium, spacing: 0.3),
    );
  }

  // ─── Emphasized cuts ───
  // Applied on top of a resolved role when a single element must dominate.

  static TextStyle emphasized(TextStyle style) => style.copyWith(
        fontWeight: _bumpWeight(style.fontWeight ?? regular),
        letterSpacing: (style.letterSpacing ?? 0) - 0.1,
      );

  static FontWeight _bumpWeight(FontWeight weight) {
    switch (weight) {
      case FontWeight.w400:
        return FontWeight.w500;
      case FontWeight.w500:
        return FontWeight.w600;
      case FontWeight.w600:
        return FontWeight.w700;
      default:
        return FontWeight.w700;
    }
  }

  /// Uppercase group label used above list sections.
  static TextStyle overline(Color color) => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: semiBold,
        letterSpacing: 0.8,
      ).copyWith(color: color);
}
