import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';

/// The two button styles the sign-in screens share.
///
/// Both screens defined these privately, with the same comment, and they are
/// the app's one deliberate departure from `filledButtonTheme`: the stadium
/// corner is right for a button that sits among other buttons, and wrong for
/// one stacked directly under an [M3ETextField], where the field's
/// `M3EShape.large` corner and 0.8 outline are what the button has to match.
///
/// The container roles are the theme's own — `primary` in the dark scheme is
/// the pale tone meant to be drawn *on* a dark surface, and using it as a fill
/// paints a near-white slab — and are repeated here only because
/// `FilledButton.styleFrom` replaces the theme's style rather than merging
/// with it.
ButtonStyle authFilledStyle(ColorScheme scheme) => FilledButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: M3EShape.border(M3EShape.large),
    );

ButtonStyle authOutlinedStyle(ColorScheme scheme) => OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      side: BorderSide(color: scheme.outlineVariant, width: 0.8),
      shape: M3EShape.border(M3EShape.large),
    );
