import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';

/// Material 3 Expressive text field.
///
/// The app had four different field treatments — bare borderless inputs, an
/// outlined one from the theme, and two hand-rolled stadium containers with
/// different radii and border widths. This is the single treatment they all
/// collapse into, so a form reads as one system.
///
/// Deliberate choices:
///
/// * **The outline is always visible.** A borderless field looks tidy in a
///   mockup and then leaves the user guessing where to tap. Focus thickens the
///   same outline and tints it rather than introducing a new shape.
/// * **The label is never only a hint.** Android drops a hint from the
///   accessible name as soon as the field has content, so a hint-only field
///   goes anonymous exactly when it holds data. [label] is published as
///   semantics regardless of what is typed.
class M3ETextField extends StatelessWidget {
  /// Names the field for both the user and assistive tech. Required.
  final String label;

  /// Example content. Optional, and never the only thing naming the field.
  final String? hint;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  final IconData? prefixIcon;
  final Widget? suffix;

  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;

  /// Hides the floating label and shows only the hint — for search fields and
  /// other single-purpose inputs where a label above would be noise.
  final bool compact;

  const M3ETextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Multi-line fields keep a rectangle; single-line compact ones are pills.
    // A stadium wrapped around six lines of text reads as a mistake.
    final radius =
        compact && (maxLines ?? 1) == 1 ? M3EShape.full : M3EShape.large;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    // MergeSemantics, not a bare Semantics wrapper. On its own, `Semantics`
    // annotates a node that sits *above* the field, so the editable node the
    // platform actually focuses stays anonymous — uiautomator reports it as
    // NAF, and `tool/adb_drive.py tap` cannot find the field by name. Merging
    // folds the label onto the editable node itself.
    return MergeSemantics(
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          style: theme.textTheme.bodyLarge,
          cursorColor: scheme.primary,
          decoration: InputDecoration(
            labelText: compact ? null : label,
            hintText: hint ?? (compact ? label : null),
            labelStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
            hintStyle: theme.textTheme.bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: scheme.onSurfaceVariant),
            suffixIcon: suffix,
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: prefixIcon == null ? 16 : 12,
              vertical: compact ? 14 : 16,
            ),
            border: border(scheme.outline, 0.8),
            enabledBorder: border(scheme.outline, 0.8),
            focusedBorder: border(scheme.primary, 1.6),
            errorBorder: border(scheme.error, 0.8),
            focusedErrorBorder: border(scheme.error, 1.6),
          ),
        ),
      ),
    );
  }
}
