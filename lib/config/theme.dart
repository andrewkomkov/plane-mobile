import 'package:flutter/material.dart';
import 'm3e/shapes.dart';
import 'm3e/typography.dart';

class PlaneTheme {
  // ─── Design system colors (from mockup CSS) ───
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceContainer = Color(0xFF201F1F);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353534);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceBright = Color(0xFF3A3939);
  static const surfaceVariant = Color(0xFF353534);

  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFC6C5D5);
  static const onBackground = Color(0xFFE5E2E1);
  static const outline = Color(0xFF908F9E);
  static const outlineVariant = Color(0xFF454652);

  static const primaryContainer = Color(0xFF5E6AD2);
  static const onPrimaryContainer = Color(0xFFFDFAFF);
  static const primary = Color(0xFFBDC2FF);
  static const inversePrimary = Color(0xFF4854BB);

  static const errorColor = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const tertiaryColor = Color(0xFFFFB867);
  static const tertiaryContainer = Color(0xFFA56500);

  static const secondaryColor = Color(0xFFC0C3F2);
  static const secondaryContainer = Color(0xFF42466E);

  // Convenience aliases matching old code
  static const _accent = Color(0xFF5E6AD2);

  // Light theme legacy colors
  static const _bgLight = Color(0xFFFFFFFF);
  static const _surfaceLight = Color(0xFFF8F8F8);
  static const _textPrimaryLight = Color(0xFF1A1A1A);
  static const _textSecondaryLight = Color(0xFF6B6B6B);

  // ─── Typography sizes (consistent across app) ───
  /// Screen titles: "My issues", "Inbox", "Projects"
  static const double fontTitle = 24;
  static const FontWeight fontTitleWeight = FontWeight.w700;

  /// Section headers: "In Progress", "Backlog", group labels
  static const double fontSection = 13;
  static const FontWeight fontSectionWeight = FontWeight.w600;

  /// Issue/item names in lists
  static const double fontBody = 15;
  static const FontWeight fontBodyWeight = FontWeight.w500;

  /// Secondary text: timestamps, IDs, subtitles
  static const double fontCaption = 12;

  /// Small chips, badges, pill labels
  static const double fontSmall = 11;

  /// Icon sizes
  static const double iconSmall = 14;
  static const double iconMedium = 16;
  static const double iconLarge = 20;

  // Priority colors
  static const urgent = Color(0xFFEF4444);
  static const high = Color(0xFFF97316);
  static const medium = Color(0xFFEAB308);
  static const low = Color(0xFF3B82F6);
  static const noPriority = Color(0xFF6B7280);

  // State group colors
  static const backlog = Color(0xFF6B7280);
  static const unstarted = Color(0xFF9CA3AF);
  static const started = Color(0xFFF59E0B);
  static const completed = Color(0xFF22C55E);
  static const cancelled = Color(0xFFEF4444);

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'urgent': return urgent;
      case 'high': return high;
      case 'medium': return medium;
      case 'low': return low;
      default: return noPriority;
    }
  }

  static Color stateGroupColor(String group) {
    switch (group) {
      case 'backlog': return backlog;
      case 'unstarted': return unstarted;
      case 'started': return started;
      case 'completed': return completed;
      case 'cancelled': return cancelled;
      default: return backlog;
    }
  }

  static IconData priorityIcon(String priority) {
    switch (priority) {
      case 'urgent': return Icons.error;
      case 'high': return Icons.signal_cellular_alt;
      case 'medium': return Icons.signal_cellular_alt_2_bar;
      case 'low': return Icons.signal_cellular_alt_1_bar;
      default: return Icons.more_horiz;
    }
  }

  static IconData stateIcon(String group) {
    switch (group) {
      case 'backlog': return Icons.circle_outlined;
      case 'unstarted': return Icons.circle_outlined;
      case 'started': return Icons.timelapse;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.circle_outlined;
    }
  }

  // Light theme surface variants
  static const _surfaceContainerLight = Color(0xFFF5F5F5);
  static const _surfaceContainerLowLight = Color(0xFFF8F8F8);
  static const _surfaceContainerHighLight = Color(0xFFEBEBEB);
  static const _surfaceContainerHighestLight = Color(0xFFE0E0E0);
  // WCAG 1.4.11 asks 3:1 of any boundary that identifies a control. The old
  // #E0E0E0 managed 1.32:1 on white — a field outline nobody could see. This
  // clears it at 3.45:1 on background and 3.25:1 on cards.
  static const _outlineLight = Color(0xFF8A8A8A);
  static const _outlineVariantLight = Color(0xFFD0D0D0);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffoldBackground: _bgLight,
        scheme: const ColorScheme.light(
          primary: _accent,
          surface: _surfaceLight,
          surfaceContainerLowest: _bgLight,
          surfaceContainerLow: _surfaceContainerLowLight,
          surfaceContainer: _surfaceContainerLight,
          surfaceContainerHigh: _surfaceContainerHighLight,
          surfaceContainerHighest: _surfaceContainerHighestLight,
          onSurface: _textPrimaryLight,
          onSurfaceVariant: _textSecondaryLight,
          outline: _outlineLight,
          outlineVariant: _outlineVariantLight,
          primaryContainer: _accent,
          onPrimaryContainer: Colors.white,
          error: Color(0xFFBA1A1A),
          errorContainer: Color(0xFFFFDAD6),
          secondary: Color(0xFF5E6AD2),
          secondaryContainer: Color(0xFFDEE0FF),
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffoldBackground: background,
        scheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
          surfaceContainerLowest: surfaceContainerLowest,
          surfaceContainerLow: surfaceContainerLow,
          surfaceContainer: surfaceContainer,
          surfaceContainerHigh: surfaceContainerHigh,
          surfaceContainerHighest: surfaceContainerHighest,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: outline,
          outlineVariant: outlineVariant,
          primaryContainer: primaryContainer,
          onPrimaryContainer: onPrimaryContainer,
          error: errorColor,
          errorContainer: errorContainer,
          secondary: secondaryColor,
          secondaryContainer: secondaryContainer,
        ),
      );

  /// Single builder for both themes.
  ///
  /// Component shapes come from the M3 Expressive corner scale — noticeably
  /// rounder than the 6–8px this app used before, which is the most visible
  /// part of the expressive language. Everything else stays deliberately flat:
  /// zero elevation, hairline outlines, no tinted overlays. That restraint is
  /// what keeps it reading as Linear rather than as stock Material.
  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBackground,
    required ColorScheme scheme,
  }) {
    final textTheme =
        M3EType.textTheme(scheme.onSurface, scheme.onSurfaceVariant);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: M3EType.fontFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: scheme.outlineVariant, width: 0.8),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      // Buttons adopt the expressive pill shape and heavier label weight.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
        ),
      ),
      // Without this the unselected thumb resolves to `outline` and the track
      // to `surfaceContainerHighest`, which in the light palette were the same
      // grey — an off switch rendered as an empty pill at 1.00:1.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest),
        trackOutlineColor:
            WidgetStateProperty.resolveWith((_) => scheme.outline),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(M3EShape.extraLargeIncreased),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.extraLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBackground,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
