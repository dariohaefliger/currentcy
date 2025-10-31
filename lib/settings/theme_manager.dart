import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light);

  static const _key = 'theme_mode';

  /// Lädt gespeicherten Modus (Light/Dark/System) beim Start
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

  /// Speichert den aktuellen Modus
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString(_key, value);
  }
}
