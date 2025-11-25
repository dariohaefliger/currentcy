import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:currentcy/settings/settings_manager.dart';

class ExchangeRatesService {
  // Base URL from exchangeratesapi docs
  static const String _baseUrl = 'https://api.exchangeratesapi.io/v1';

  /// Fetches the latest rates.
  ///
  /// On the free plan the base is always EUR, so it is adjusted to that.
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

    // Ensure EUR exists as 1.0, even if not in the map
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
  ///   DateTime (day, no time) -> Map with code, rate
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

      result[dateOnly] = dayRates;
    }

    return result;
  }
}
