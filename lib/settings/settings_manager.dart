import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const _keyApiKey = 'exchangerates_api_key';
  static const _keyLastSync = 'last_sync_time';
  static const _keyUseMockRates = 'use_mock_rates';

  // Favourite currencies
  static const _keyFav1 = 'favorite_currency_1';
  static const _keyFav2 = 'favorite_currency_2';
  static const _keyFav3 = 'favorite_currency_3';

  // ===== API KEY =====
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
  }

  static Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  // ===== LAST SYNC TIME =====
  static Future<void> saveLastSync(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, time.toIso8601String());
  }

  static Future<DateTime?> loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSync);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // ===== USE MOCK RATES TOGGLE =====
  static Future<void> saveUseMockRates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseMockRates, value);
  }

  static Future<bool> loadUseMockRates() async {
    final prefs = await SharedPreferences.getInstance();
    // default to true so app works even without API key
    return prefs.getBool(_keyUseMockRates) ?? true;
  }

  // ===== FAVOURITE CURRENCIES =====
  //
  // Handles 3 favourites.
  // Defaults if nothing stored yet: CHF, EUR, USD

  static Future<void> saveFavoriteCurrencies(
    List<String> favorites,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // normalize to length 3
    final normalized = List<String>.from(favorites);
    while (normalized.length < 3) {
      normalized.add('');
    }

    await prefs.setString(_keyFav1, normalized[0]);
    await prefs.setString(_keyFav2, normalized[1]);
    await prefs.setString(_keyFav3, normalized[2]);
  }

  static Future<List<String>> loadFavoriteCurrencies() async {
    final prefs = await SharedPreferences.getInstance();

    final f1 = prefs.getString(_keyFav1);
    final f2 = prefs.getString(_keyFav2);
    final f3 = prefs.getString(_keyFav3);

    // If nothing stored yet, return defaults
    if (f1 == null && f2 == null && f3 == null) {
      return ['CHF', 'EUR', 'USD'];
    }

    return [
      f1 ?? 'CHF',
      f2 ?? 'EUR',
      f3 ?? 'USD',
    ];
  }
}
