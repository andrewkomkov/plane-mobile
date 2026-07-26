// For `CupertinoPageTransitionsBuilder`, which material.dart does not re-export
// and which iOS keeps for its edge-swipe back gesture.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'm3e/page_transitions.dart';
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
  // Sits one step below the scaffold and one above surfaceContainerLow — see
  // the ramp note further down.
  static const _surfaceLight = Color(0xFFFCFCFC);
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

  // Priority and state colours.
  //
  // These carry meaning rather than decoration, so they are not part of the
  // ColorScheme — but they are still drawn on a surface, and the surface
  // changes with the theme. The base set was picked against near-black. On
  // white the light hues collapse: amber `started` measures 2.02:1 and yellow
  // `medium` 1.81:1 against `_surfaceLight`, where WCAG 1.4.11 asks 3:1 of any
  // icon carrying information.
  //
  // So each token that fails gets a darker twin for light mode, same hue,
  // measured at 4.6:1 or better. The four that already pass on both — urgent,
  // low, noPriority, cancelled — keep one value, because a colour that works is
  // better left recognisable across themes.

  // Priority colors
  static const urgent = Color(0xFFEF4444);
  static const high = Color(0xFFF97316);
  static const medium = Color(0xFFEAB308);
  static const low = Color(0xFF3B82F6);
  static const noPriority = Color(0xFF6B7280);

  static const _highLight = Color(0xFFC2410C);
  static const _mediumLight = Color(0xFFA16207);

  // State group colors
  static const backlog = Color(0xFF6B7280);
  static const unstarted = Color(0xFF9CA3AF);
  static const started = Color(0xFFF59E0B);
  static const completed = Color(0xFF22C55E);
  static const cancelled = Color(0xFFEF4444);

  static const _unstartedLight = Color(0xFF4B5563);
  static const _startedLight = Color(0xFFB45309);
  static const _completedLight = Color(0xFF15803D);

  // Unsynced work waiting to upload. Material has no warning role, and the
  // sync affordances were reaching for a raw amber that measures 2.02:1 on a
  // light surface — the same hex, and the same failure, as `started` had.
  static const _pending = Color(0xFFF59E0B);
  static const _pendingLight = Color(0xFFB45309);

  static bool _isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color pendingColor(BuildContext context) =>
      _isLight(context) ? _pendingLight : _pending;

  // Identifier badges, cycled by list position. These draw the identifier as
  // text over a 20%-alpha wash of themselves, so they carry a text contrast
  // requirement, not an icon one.
  //
  // The single set they replaced was a row of dark-theme scheme values written
  // out as hex, and it failed in both directions: three of them landed near
  // 2:1 on dark and the green managed 2.15:1 on light. Two sets, each measured
  // at 4.5:1 or better against its own surfaces.
  static const _badgeDark = [
    Color(0xFF8B93E8), // indigo
    Color(0xFFE3A008), // amber
    Color(0xFF2DD4BF), // teal
    Color(0xFFFB7185), // rose
    Color(0xFFC084FC), // violet
    Color(0xFF4ADE80), // green
  ];

  static const _badgeLight = [
    Color(0xFF4338CA),
    Color(0xFFA16207),
    Color(0xFF0F766E),
    Color(0xFFBE123C),
    Color(0xFF7E22CE),
    Color(0xFF15803D),
  ];

  static Color projectBadgeColor(BuildContext context, int index) {
    final set = _isLight(context) ? _badgeLight : _badgeDark;
    return set[index % set.length];
  }

  /// How many distinct badge hues exist, so a test can walk all of them.
  static int get projectBadgeCount => _badgeDark.length;

  /// Pairs with [pendingColor] as a fill. The two ambers sit on opposite sides
  /// of the range, so what reads on one is invisible on the other.
  static Color onPendingColor(BuildContext context) =>
      _isLight(context) ? Colors.white : Colors.black;

  static Color priorityColor(BuildContext context, String priority) {
    final light = _isLight(context);
    switch (priority) {
      case 'urgent': return urgent;
      case 'high': return light ? _highLight : high;
      case 'medium': return light ? _mediumLight : medium;
      case 'low': return low;
      default: return noPriority;
    }
  }

  static Color stateGroupColor(BuildContext context, String group) {
    final light = _isLight(context);
    switch (group) {
      case 'backlog': return backlog;
      case 'unstarted': return light ? _unstartedLight : unstarted;
      case 'started': return light ? _startedLight : started;
      case 'completed': return light ? _completedLight : completed;
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
      // Backlog and unstarted used to share this glyph and differ only by two
      // greys 1.9:1 apart, which in a list is no difference at all. The state
      // is the one thing an issue row has to say, so it says it in shape:
      // queued dots for backlog, an empty ring for a todo not yet picked up.
      case 'backlog': return Icons.pending_outlined;
      case 'unstarted': return Icons.circle_outlined;
      case 'started': return Icons.timelapse;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.circle_outlined;
    }
  }

  // Light theme surface variants.
  //
  // The ramp has to descend in luminance at every step, because that descent is
  // the only thing separating a card from the page behind it. It did not:
  // `surface` and `surfaceContainerLow` were both #F8F8F8, so every card, tile
  // and text field fill in light mode was exactly the colour it sat on and only
  // its outline said where it ended. The dark ramp was stepped correctly all
  // along; this was light-only.
  static const _surfaceContainerLight = Color(0xFFF2F2F2);
  static const _surfaceContainerLowLight = Color(0xFFF7F7F7);
  static const _surfaceContainerHighLight = Color(0xFFECECEC);
  static const _surfaceContainerHighestLight = Color(0xFFE5E5E5);
  // WCAG 1.4.11 asks 3:1 of any boundary that identifies a control. The old
  // #E0E0E0 managed 1.32:1 on white — a field outline nobody could see. This
  // clears it at 3.45:1 on background and 3.22:1 on cards.
  static const _outlineLight = Color(0xFF8A8A8A);
  static const _outlineVariantLight = Color(0xFFD0D0D0);

  /// How the system status bar is drawn over a given theme.
  ///
  /// This used to be set once in `main()` and pinned to `Brightness.light`,
  /// which names the *icon* colour on Android: white clock, white battery,
  /// white signal — on a `#FFFFFF` scaffold. The entire light theme shipped
  /// with an unreadable status bar, and because it was set imperatively at
  /// startup it did not follow the user switching themes either.
  ///
  /// Applied through an `AnnotatedRegion` in `main.dart`, so it is re-derived
  /// from whichever theme is live rather than being a one-shot.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final light = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // The two platforms name this from opposite ends: Android's
      // `statusBarIconBrightness` is the brightness of the icons, iOS's
      // `statusBarBrightness` is the brightness of what sits behind them. Both
      // have to be set, and they are always opposites.
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      // The navigation bar is deliberately left alone: the app draws a floating
      // glass bar of its own over an `extendBody` scaffold, and taking the
      // system bar transparent from here without owning the insets would put
      // list content under it.
    );
  }

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
      // The ambient icon colour was the last literal left in the app: Material
      // defaults it to `black87` on light and pure `white` on dark, neither of
      // which is a role. `onSurface` is within a step of both, so nothing moves
      // visually — but it means an icon with no colour of its own now agrees
      // with the text beside it by construction, and it gives widgets a stable
      // value to recognise. `M3ELoadingIndicator` uses exactly that: an ambient
      // icon colour that is *not* this one means something up the tree — a
      // filled button's foreground — has claimed it, and the indicator follows
      // it instead of painting the accent onto the button's own fill.
      iconTheme: IconThemeData(color: scheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
      // Springs, not curves — including the largest movement in the app.
      //
      // Every push was a stock platform transition, which on Android means
      // Flutter's own approximation of an expressive spring with a 450ms cubic.
      // One builder here replaces all 47 of them; no call site changes. iOS and
      // macOS keep `CupertinoPageTransitionsBuilder`, because that is where the
      // interactive edge-swipe back gesture lives and losing it would cost more
      // than the motion gains.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: M3ESpringPageTransitionsBuilder(),
          TargetPlatform.fuchsia: M3ESpringPageTransitionsBuilder(),
          TargetPlatform.linux: M3ESpringPageTransitionsBuilder(),
          TargetPlatform.windows: M3ESpringPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        // No Material `AppBar` survives in `lib/` — every bar is `M3EAppBar` —
        // but a bar that did appear would otherwise re-pin the overlay style to
        // its own guess and undo the annotated region.
        systemOverlayStyle: overlayStyle(brightness),
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
      //
      // The fill has to be named. Left to M3's default a `FilledButton` paints
      // `colorScheme.primary`, and in the dark scheme that is `#BDC2FF` — the
      // *pale* tone, the one meant to sit on a dark surface, not to be one. Two
      // screens had already worked around it locally with a copy of this style
      // and two more had not, so a filled button meant one thing on the setup
      // screen and another on the profile screen.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
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
      // The three floating surfaces all carry the hairline.
      //
      // "Flat everywhere, hairline outlines" is the documented trade against
      // M3E's tonal elevation, and `popupMenuTheme` below was the only place it
      // had actually been carried out. On the dark ramp the surface steps do
      // the job on their own; on the light one they do not — a floating
      // snackbar is `#E5E5E5` on `#FFFFFF`, 1.13:1, with nothing at its edge to
      // say where it ends. In a zero-elevation app the hairline *is* the
      // boundary, and a surface that floats over arbitrary content needs one.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(M3EShape.extraLargeIncreased),
          ),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.extraLarge),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(M3EShape.large),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
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
