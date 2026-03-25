import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/secure_storage.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final value = await SecureStorage.getThemeMode();
    if (value != null) {
      state = _fromString(value);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await SecureStorage.saveThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(() => ThemeModeNotifier());
