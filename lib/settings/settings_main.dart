import 'package:flutter/material.dart';
import 'package:currentcy/settings/theme_manager.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    bool isDark = ThemeManager.themeModeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'App Appearance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark theme'),
            value: isDark,
            onChanged: (value) {
              final newMode = value ? ThemeMode.dark : ThemeMode.light;
              ThemeManager.themeModeNotifier.value = newMode;
              ThemeManager.saveThemeMode(newMode);
              setState(() {});
            },
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
        ],
      ),
    );
  }
}
