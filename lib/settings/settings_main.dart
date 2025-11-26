// -----------------------------------------------------------------------------
// currentcy – Settings Screen
//
// This file contains:
// - [Settings] screen with app-level configuration
//
// Responsibilities:
// - Toggle app theme (light/dark)
// - Configure ExchangeRates API (API key, mock mode, premium plan)
// - Manage favourite currencies used across the app
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:currentcy/settings/theme_manager.dart';
import 'package:currentcy/settings/settings_manager.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/exchange_rates_info.dart';

/// Settings page for the currentcy app.
///
/// Allows the user to:
/// - switch between light and dark mode
/// - configure favourite currencies
/// - manage ExchangeRates API settings (mock mode, API key, premium plan)
class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  /// Controller for editing the ExchangeRates API key.
  final TextEditingController _apiKeyController = TextEditingController();

  /// True while settings and currency options are being loaded.
  bool _isLoading = true;

  /// Whether mock rates are used instead of live data.
  bool _useMockRates = true;

  /// Whether the user has a Professional / Business plan for live history.
  bool _hasPremiumPlan = false;

  /// Favourite currencies (ISO codes) displayed in the settings list.
  List<String> _favoriteCurrencies = ['CHF', 'EUR', 'USD'];

  /// All available currency codes for favourite pickers.
  List<String> _currencyOptions = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads persisted settings and initializes local state.
  ///
  /// Loads:
  /// - API key
  /// - mock mode flag
  /// - premium plan flag
  /// - favourite currencies
  /// - currency options (based on mock rates)
  Future<void> _loadSettings() async {
    final apiKey = await SettingsManager.loadApiKey();
    final useMock = await SettingsManager.loadUseMockRates();
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final hasPremium = await SettingsManager.loadHasPremiumPlan();

    // Use mock rates to build options so the picker always has stable values.
    final options = CurrencyRepository.getCurrencyCodes(true);

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _useMockRates = useMock;
      _hasPremiumPlan = hasPremium;
      _favoriteCurrencies = List<String>.from(favs);
      _currencyOptions = options;
      _isLoading = false;
    });
  }

  /// Persists the API key and shows a confirmation message.
  Future<void> _saveApiKey() async {
    await SettingsManager.saveApiKey(_apiKeyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved')),
    );
  }

  /// Toggles mock mode and persists the new value.
  Future<void> _toggleMockRates(bool value) async {
    setState(() {
      _useMockRates = value;
    });
    await SettingsManager.saveUseMockRates(value);
  }

  /// Toggles premium plan flag and persists the new value.
  ///
  /// Used by the charts screen to decide whether live historical data
  /// is allowed.
  Future<void> _togglePremiumPlan(bool value) async {
    setState(() {
      _hasPremiumPlan = value;
    });
    await SettingsManager.saveHasPremiumPlan(value);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  // --------------------------
  // FAVOURITE PICKER (BOTTOM SHEET)
  // --------------------------

  /// Opens a searchable bottom sheet for choosing a favourite currency.
  ///
  /// Updates the entry at [index] in [_favoriteCurrencies] when a value
  /// is selected, and persists the updated favourites.
  Future<void> _pickFavoriteCurrency(int index) async {
    if (_currencyOptions.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();
        List<String> filtered = List.of(_currencyOptions);

        void applyFilter(String q) {
          final query = q.toLowerCase();
          filtered = _currencyOptions.where((code) {
            final name = CurrencyRepository.nameFor(code).toLowerCase();
            return code.toLowerCase().contains(query) ||
                name.contains(query);
          }).toList();
        }

        // Initial state: no filter.
        applyFilter('');

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 70),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              top: false,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle.
                        Container(
                          width: 40,
                          height: 4,
                          margin:
                              const EdgeInsets.only(top: 8, bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Search field.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 8),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:
                                  'Search currency (code or name)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(12)),
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() => applyFilter(value));
                            },
                          ),
                        ),

                        // List of currencies.
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final code = filtered[i];
                              final flag =
                                  CurrencyRepository.flagFor(code);
                              final name =
                                  CurrencyRepository.nameFor(code);
                              return ListTile(
                                leading: Text(
                                  flag,
                                  style:
                                      const TextStyle(fontSize: 28),
                                ),
                                title: Text(name),
                                subtitle: Text(code),
                                onTap: () =>
                                    Navigator.of(context).pop(code),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _favoriteCurrencies[index] = selected;
      });
      await SettingsManager.saveFavoriteCurrencies(
          _favoriteCurrencies);
    }
  }

  /// Builds a single list tile for a favourite currency.
  Widget _buildFavouriteTile(int index) {
    final code = _favoriteCurrencies[index];
    final name = CurrencyRepository.nameFor(code);
    final flag = CurrencyRepository.flagFor(code);

    return ListTile(
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(name),
      subtitle: Text(code),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _pickFavoriteCurrency(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.themeModeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Close settings and return to previous screen.
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text(
                    'Switch between light and dark theme',
                  ),
                  value: isDark,
                  onChanged: (value) {
                    final newMode =
                        value ? ThemeMode.dark : ThemeMode.light;
                    ThemeManager.themeModeNotifier.value = newMode;
                    ThemeManager.saveThemeMode(newMode);
                    setState(() {});
                  },
                  secondary: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                  ),
                ),
                const SizedBox(height: 24),

                // ===== Favourite currencies =====
                const Text(
                  'Favourite currencies',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFavouriteTile(0),
                _buildFavouriteTile(1),
                _buildFavouriteTile(2),
                const SizedBox(height: 24),

                // ===== Exchange Rates API header with info icon =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ExchangeRates API',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'How to set up the API',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ExchangeRatesInfoPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mock mode toggle.
                SwitchListTile(
                  title: const Text('Use mock rates'),
                  subtitle: const Text(
                    'When enabled, conversions use built-in test values.',
                  ),
                  value: _useMockRates,
                  onChanged: _toggleMockRates,
                  secondary: const Icon(Icons.science),
                ),

                // Premium / Business plan toggle.
                SwitchListTile(
                  title: const Text('Professional / Business plan'),
                  subtitle: const Text(
                    'Enable this if your exchangeratesapi.io subscription is '
                    'Professional or Business. Required for live historical charts.',
                  ),
                  value: _hasPremiumPlan,
                  onChanged: _togglePremiumPlan,
                  secondary: const Icon(Icons.workspace_premium),
                ),

                const SizedBox(height: 8),

                // API key input.
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API key',
                    border: OutlineInputBorder(),
                    hintText:
                        'Paste your exchangeratesapi.io API key here',
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
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}
