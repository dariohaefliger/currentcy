import 'package:flutter/material.dart';
import 'package:currentcy/settings/theme_manager.dart';
import 'package:currentcy/settings/settings_manager.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isLoading = true;
  bool _useMockRates = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await SettingsManager.loadApiKey();
    final useMock = await SettingsManager.loadUseMockRates();

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _useMockRates = useMock;
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    await SettingsManager.saveApiKey(_apiKeyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved')),
    );
  }

  Future<void> _toggleMockRates(bool value) async {
    setState(() {
      _useMockRates = value;
    });
    await SettingsManager.saveUseMockRates(value);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ===== Appearance =====
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
                const SizedBox(height: 24),

                // ===== Exchange Rates API =====
                const Text(
                  'ExchangeRates API',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Use mock rates'),
                  subtitle: const Text(
                      'When enabled, conversions use built-in test values.'),
                  value: _useMockRates,
                  onChanged: _toggleMockRates,
                  secondary: const Icon(Icons.science),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API key',
                    border: OutlineInputBorder(),
                    hintText: 'Paste your exchangeratesapi.io API key here',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saveApiKey,
                  child: const Text('Save API key'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Disable "Use mock rates" to fetch live exchange rates using this key.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    );
  }
}
