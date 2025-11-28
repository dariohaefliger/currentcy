// -----------------------------------------------------------------------------
// currentcy – Exchange Rates Service
//
// This file contains:
// - [ExchangeRatesService] for talking to exchangeratesapi.io
//
// Responsibilities:
// - Fetch latest live EUR-based FX rates
// - Fetch historical FX data for a base/quote pair for the last N days
// - Handle API key loading and basic error handling
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:currentcy/settings/settings_manager.dart';

/// Low-level HTTP client for exchangeratesapi.io.
///
/// Provides static methods to fetch:
/// - latest rates (EUR-based)
/// - historical rates for a base/quote pair
///
/// This service is pure I/O and does not cache anything itself; callers are
/// expected to store data (e.g. in [CurrencyRepository]).
class ExchangeRatesService {
  /// Base URL from exchangeratesapi.io docs.
  static const String _baseUrl = 'https://api.exchangeratesapi.io/v1';

  /// Fetches the latest rates from the `/latest` endpoint.
  ///
  /// Behaviour:
  /// - Requires a valid API key from [SettingsManager.loadApiKey].
  /// - Expects the response to be EUR-based (free plan limitation).
  /// - Returns a map: `currencyCode -> rate`.
  ///
  /// Throws:
  /// - [Exception] when the API key is missing or HTTP/API errors occur.
  static Future<Map<String, double>> fetchLatestRates() async {
    final apiKey = await SettingsManager.loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not set. Please configure it in Settings.');
    }

    final uri = Uri.parse('$_baseUrl/latest?access_key=$apiKey');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rates: HTTP ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final success = data['success'] as bool? ?? false;
    if (!success) {
      final error = data['error'];
      throw Exception('API error: $error');
    }

    final rawRates = Map<String, dynamic>.from(data['rates'] as Map);

    final rates = rawRates.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    // Ensure EUR exists as 1.0, even if not in the map (defensive).
    if (!rates.containsKey('EUR')) {
      return {
        'EUR': 1.0,
        ...rates,
      };
    }

    return rates;
  }

  /// Fetches historical rates (EUR-based) for the last [days] days.
  ///
  /// Returns a map:
  ///   `DateTime (day, no time)` -> `Map<currencyCode, rate>`
  ///
  /// Behaviour:
  /// - Requires a valid API key from [SettingsManager.loadApiKey].
  /// - Issues one request per day to `/YYYY-MM-DD` with `symbols=base,quote`.
  ///
  /// Throws:
  /// - [Exception] for missing API key or HTTP/API errors.
  /// - [ArgumentError] when [days] is less than 1.
  static Future<Map<DateTime, Map<String, double>>> fetchHistoricalRates({
    required String base,
    required String quote,
    int days = 5,
  }) async {
    final apiKey = await SettingsManager.loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not set. Please configure it in Settings.');
    }
    if (days < 1) {
      throw ArgumentError.value(days, 'days', 'must be >= 1');
    }

    final now = DateTime.now().toUtc();
    final result = <DateTime, Map<String, double>>{};

    for (int i = 0; i < days; i++) {
      final day = now.subtract(Duration(days: i));
      final dateOnly = DateTime(day.year, day.month, day.day);

      // Format as YYYY-MM-DD for API path segment.
      final dateStr =
          '${dateOnly.year.toString().padLeft(4, '0')}-'
          '${dateOnly.month.toString().padLeft(2, '0')}-'
          '${dateOnly.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse(
        '$_baseUrl/$dateStr?access_key=$apiKey&symbols=$base,$quote',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch historical rates for $dateStr: '
          'HTTP ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      final success = data['success'] as bool? ?? false;
      if (!success) {
        final error = data['error'];
        throw Exception('API error on $dateStr: $error');
      }

      final rawRates = Map<String, dynamic>.from(data['rates'] as Map);
      final dayRates = rawRates.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );

      // Store normalized date-only key.
      result[dateOnly] = dayRates;
    }

    return result;
  }
}
