// -----------------------------------------------------------------------------
// currentcy – Settings Persistence
//
// This file contains:
// - [SettingsManager] a static utility for storing and retrieving app settings
//
// Responsibilities:
// - Persist user selections (API key, mock toggle, premium plan)
// - Provide default values where appropriate
// - Handle favourite currencies and last sync timestamp
//
// Uses: shared_preferences
// -----------------------------------------------------------------------------

import 'package:shared_preferences/shared_preferences.dart';

/// Utility class managing all persistent app settings.
///
/// The manager reads/writes simple values using [SharedPreferences].
/// All methods are static for convenience.
class SettingsManager {
  // Keys for SharedPreferences
  static const _keyApiKey = 'exchangerates_api_key';
  static const _keyLastSync = 'last_sync_time';
  static const _keyUseMockRates = 'use_mock_rates';
  static const _keyFavoriteCurrencies = 'favorite_currencies';
  static const _keyHasPremiumPlan = 'has_premium_plan';

  // ==========================================================================
  // API KEY
  // ==========================================================================

  /// Saves the ExchangeRates API key.
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
  }

  /// Loads the ExchangeRates API key, or null if not set.
  static Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  // ==========================================================================
  // LAST SYNC TIME
  // ==========================================================================

  /// Saves the timestamp of the last successful sync (ISO 8601).
  static Future<void> saveLastSync(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, time.toIso8601String());
  }

  /// Loads the last sync time as a [DateTime], or null if never synced.
  static Future<DateTime?> loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSync);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // ==========================================================================
  // USE MOCK RATES
  // ==========================================================================

  /// Saves whether mock rates should be used instead of live data.
  static Future<void> saveUseMockRates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseMockRates, value);
  }

  /// Loads the mock flag. Defaults to `true` so the app works without setup.
  static Future<bool> loadUseMockRates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseMockRates) ?? true;
  }

  // ==========================================================================
  // FAVORITE CURRENCIES
  // ==========================================================================

  /// Saves the list of favourite currencies (ISO codes).
  static Future<void> saveFavoriteCurrencies(List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavoriteCurrencies, codes);
  }

  /// Loads favourite currencies, or defaults to CHF, EUR, USD.
  static Future<List<String>> loadFavoriteCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyFavoriteCurrencies);
    if (list == null || list.isEmpty) {
      return ['CHF', 'EUR', 'USD'];
    }
    return List<String>.from(list);
  }

  // ==========================================================================
  // PREMIUM PLAN
  // ==========================================================================

  /// Saves whether the user has a Professional / Business plan.
  ///
  /// This determines whether live historical charts may be loaded.
  static Future<void> saveHasPremiumPlan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasPremiumPlan, value);
  }

  /// Loads the premium plan flag. Defaults to `false`.
  static Future<bool> loadHasPremiumPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasPremiumPlan) ?? false;
  }
}
