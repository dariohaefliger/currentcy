// -----------------------------------------------------------------------------
// currentcy – Theme Manager
//
// This file provides:
// - A global [ValueNotifier] for reacting to theme changes
// - Persistence of the selected ThemeMode using SharedPreferences
//
// Notes:
// - Only Light and Dark modes are explicitly stored.
// - System mode is restored only if no saved preference exists.
// - UI components listen to [themeModeNotifier] to update instantly.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized theme controller for the application.
///
/// Manages:
/// - The current [ThemeMode] through a global [ValueNotifier]
/// - Persistent storage of the selected theme
///
/// Usage:
/// ```dart
/// ThemeManager.themeModeNotifier.value = ThemeMode.dark;
/// await ThemeManager.saveThemeMode(ThemeMode.dark);
/// ```
class ThemeManager {
  /// Holds the current theme mode and notifies listeners on change.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light);

  /// SharedPreferences key for persisting theme mode.
  static const _key = 'theme_mode';

  // ---------------------------------------------------------------------------
  // Load & Save
  // ---------------------------------------------------------------------------

  /// Loads the stored theme mode from SharedPreferences.
  ///
  /// If nothing is stored, the app defaults to [ThemeMode.system].
  static Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    if (saved == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (saved == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.system;
    }
  }

  /// Saves the current theme mode.
  ///
  /// Note: Only `"light"` or `"dark"` are persisted.  
  /// If the user selects system mode, nothing else is saved,
  /// so next launch will default to system mode again.
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    // System mode is treated implicitly → not saved as its own value.
    final value = mode == ThemeMode.dark ? 'dark' : 'light';

    await prefs.setString(_key, value);
  }
}
