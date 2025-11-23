import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const _keyApiKey = 'exchangerates_api_key';
  static const _keyLastSync = 'last_sync_time';
  static const _keyUseMockRates = 'use_mock_rates';

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
}
