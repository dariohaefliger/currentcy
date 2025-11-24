import 'package:flutter/material.dart';
import 'package:currentcy/settings/theme_manager.dart';
import 'package:currentcy/settings/settings_manager.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/exchange_rates_info.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isLoading = true;
  bool _useMockRates = true;

  // favourite currencies (ISO codes)
  List<String> _favoriteCurrencies = ['CHF', 'EUR', 'USD'];

  // all available codes for picker
  List<String> _currencyOptions = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await SettingsManager.loadApiKey();
    final useMock = await SettingsManager.loadUseMockRates();
    final favs = await SettingsManager.loadFavoriteCurrencies();

    final options = CurrencyRepository.getCurrencyCodes(true);

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _useMockRates = useMock;
      _favoriteCurrencies = List<String>.from(favs);
      _currencyOptions = options;
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

  // --------------------------
  // FAVOURITE PICKER (FLOATING SHEET)
  // --------------------------

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
                        // Grabber
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

                        // Search field
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

                        // List of currencies
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

                // ===== Exchange Rates API (mit Info-Icon rechts) =====
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

                SwitchListTile(
                  title: const Text('Use mock rates'),
                  subtitle: const Text(
                    'When enabled, conversions use built-in test values.',
                  ),
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
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
    );
  }
}
