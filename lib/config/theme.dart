import 'package:flutter/material.dart';

class PlaneTheme {
  // Linear-inspired colors
  static const _bgDark = Color(0xFF0A0A0A);
  static const _surfaceDark = Color(0xFF141414);
  static const _borderDark = Color(0xFF252525);
  static const _textPrimaryDark = Color(0xFFF1F1F1);
  static const _textSecondaryDark = Color(0xFF8A8A8A);

  static const _bgLight = Color(0xFFFFFFFF);
  static const _surfaceLight = Color(0xFFF8F8F8);
  static const _borderLight = Color(0xFFE8E8E8);
  static const _textPrimaryLight = Color(0xFF1A1A1A);
  static const _textSecondaryLight = Color(0xFF6B6B6B);

  static const _accent = Color(0xFF5E6AD2);

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

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgLight,
        colorScheme: ColorScheme.light(
          primary: _accent,
          surface: _surfaceLight,
          onSurface: _textPrimaryLight,
          outline: _borderLight,
          onSurfaceVariant: _textSecondaryLight,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgLight,
          foregroundColor: _textPrimaryLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textPrimaryLight,
          ),
        ),
        cardTheme: CardTheme(
          color: _bgLight,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _borderLight, width: 0.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: _borderLight,
          thickness: 0.5,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _surfaceLight,
          side: const BorderSide(color: _borderLight, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          labelStyle: const TextStyle(fontSize: 12, color: _textPrimaryLight),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderLight),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _bgLight,
          selectedItemColor: _textPrimaryLight,
          unselectedItemColor: _textSecondaryLight,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );

  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bgDark,
        colorScheme: ColorScheme.dark(
          primary: _accent,
          surface: _surfaceDark,
          onSurface: _textPrimaryDark,
          outline: _borderDark,
          onSurfaceVariant: _textSecondaryDark,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgDark,
          foregroundColor: _textPrimaryDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textPrimaryDark,
          ),
        ),
        cardTheme: CardTheme(
          color: _surfaceDark,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _borderDark, width: 0.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: _borderDark,
          thickness: 0.5,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _surfaceDark,
          side: const BorderSide(color: _borderDark, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          labelStyle: const TextStyle(fontSize: 12, color: _textPrimaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderDark),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _bgDark,
          selectedItemColor: _textPrimaryDark,
          unselectedItemColor: _textSecondaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );
}
