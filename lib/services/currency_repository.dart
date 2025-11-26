// -----------------------------------------------------------------------------
// currentcy – Currency Repository
//
// This file contains:
// - [HistoryPoint] data model for historical rates
// - [CurrencyRepository] static utilities for currency data
//
// Responsibilities:
// - Provide mock and live FX rates via [ExchangeRatesService]
// - Cache last sync timestamp and available currency codes
// - Expose currency metadata (flags, full names)
// - Generate historical series for charts (mock or live)
// -----------------------------------------------------------------------------

import 'package:currentcy/services/exchange_rates_service.dart';
import 'package:currentcy/settings/settings_manager.dart';

/// Simple data model for a historical rate point.
///
/// [date] is always truncated to a calendar day (no time-of-day semantics).
/// [rate] is the cross rate for base → quote on that day.
class HistoryPoint {
  final DateTime date;
  final double rate;

  const HistoryPoint({required this.date, required this.rate});
}

/// In-memory repository for currency-related data.
///
/// Provides:
/// - Mock rate generation and storage
/// - Live rate synchronization via [ExchangeRatesService]
/// - Historical rate series for a base/quote pair
/// - Currency metadata (flags, display names)
///
/// All methods and fields are static; this class is not meant to be
/// instantiated.
class CurrencyRepository {
  /// Base set of supported currency codes **before the first live sync**.
  static final Set<String> _baseCodes = {
    'AUD',
    'CAD',
    'CHF',
    'CNY',
    'EUR',
    'GBP',
    'JPY',
    'NZD',
    'SEK',
    'USD',
  };

  /// All known codes = base codes + codes seen in API responses.
  static final Set<String> _allCodes = {..._baseCodes};

  /// Mock rates; built from [_allCodes] in alphabetical order:
  /// 1.00, 1.01, 1.02, ...
  static Map<String, double> _mockRates = _buildMockRates();

  /// Live rates from API (EUR-based free plan).
  static Map<String, double>? _liveRates;

  /// Last sync time for live rates (local time).
  static DateTime? _lastSync;

  /// Currency code → flag emoji.
  ///
  /// Note: For some shared currencies (XAF, XOF, XCD), one representative
  /// country flag is picked.
  static final Map<String, String> _flags = {
    'AED': '🇦🇪',
    'AFN': '🇦🇫',
    'ALL': '🇦🇱',
    'AMD': '🇦🇲',
    'ANG': '🇳🇱',
    'AOA': '🇦🇴',
    'ARS': '🇦🇷',
    'AUD': '🇦🇺',
    'AWG': '🇦🇼',
    'AZN': '🇦🇿',
    'BAM': '🇧🇦',
    'BBD': '🇧🇧',
    'BDT': '🇧🇩',
    'BGN': '🇧🇬',
    'BHD': '🇧🇭',
    'BIF': '🇧🇮',
    'BMD': '🇧🇲',
    'BND': '🇧🇳',
    'BOB': '🇧🇴',
    'BRL': '🇧🇷',
    'BSD': '🇧🇸',
    'BTC': '₿',
    'BTN': '🇧🇹',
    'BWP': '🇧🇼',
    'BYR': '🇧🇾',
    'BZD': '🇧🇿',
    'CAD': '🇨🇦',
    'CDF': '🇨🇩',
    'CHF': '🇨🇭',
    'CLF': '🇨🇱',
    'CLP': '🇨🇱',
    'CNY': '🇨🇳',
    'COP': '🇨🇴',
    'CRC': '🇨🇷',
    'CUC': '🇨🇺',
    'CUP': '🇨🇺',
    'CVE': '🇨🇻',
    'CZK': '🇨🇿',
    'DJF': '🇩🇯',
    'DKK': '🇩🇰',
    'DOP': '🇩🇴',
    'DZD': '🇩🇿',
    'EGP': '🇪🇬',
    'ERN': '🇪🇷',
    'ETB': '🇪🇹',
    'EUR': '🇪🇺',
    'FJD': '🇫🇯',
    'FKP': '🇫🇰',
    'GBP': '🇬🇧',
    'GEL': '🇬🇪',
    'GGP': '🇬🇬',
    'GHS': '🇬🇭',
    'GIP': '🇬🇮',
    'GMD': '🇬🇲',
    'GNF': '🇬🇳',
    'GTQ': '🇬🇹',
    'GYD': '🇬🇾',
    'HKD': '🇭🇰',
    'HNL': '🇭🇳',
    'HRK': '🇭🇷',
    'HTG': '🇭🇹',
    'HUF': '🇭🇺',
    'IDR': '🇮🇩',
    'ILS': '🇮🇱',
    'IMP': '🇮🇲',
    'INR': '🇮🇳',
    'IQD': '🇮🇶',
    'IRR': '🇮🇷',
    'ISK': '🇮🇸',
    'JEP': '🇯🇪',
    'JMD': '🇯🇲',
    'JOD': '🇯🇴',
    'JPY': '🇯🇵',
    'KES': '🇰🇪',
    'KGS': '🇰🇬',
    'KHR': '🇰🇭',
    'KMF': '🇰🇲',
    'KPW': '🇰🇵',
    'KRW': '🇰🇷',
    'KWD': '🇰🇼',
    'KYD': '🇰🇾',
    'KZT': '🇰🇿',
    'LAK': '🇱🇦',
    'LBP': '🇱🇧',
    'LKR': '🇱🇰',
    'LRD': '🇱🇷',
    'LSL': '🇱🇸',
    // 'LTL': no current flag
    // 'LVL': no current flag
    'LYD': '🇱🇾',
    'MAD': '🇲🇦',
    'MDL': '🇲🇩',
    'MGA': '🇲🇬',
    'MKD': '🇲🇰',
    'MMK': '🇲🇲',
    'MNT': '🇲🇳',
    'MOP': '🇲🇴',
    'MRO': '🇲🇷',
    'MUR': '🇲🇺',
    'MVR': '🇲🇻',
    'MWK': '🇲🇼',
    'MXN': '🇲🇽',
    'MYR': '🇲🇾',
    'MZN': '🇲🇿',
    'NAD': '🇳🇦',
    'NGN': '🇳🇬',
    'NIO': '🇳🇮',
    'NOK': '🇳🇴',
    'NPR': '🇳🇵',
    'NZD': '🇳🇿',
    'OMR': '🇴🇲',
    'PAB': '🇵🇦',
    'PEN': '🇵🇪',
    'PGK': '🇵🇬',
    'PHP': '🇵🇭',
    'PKR': '🇵🇰',
    'PLN': '🇵🇱',
    'PYG': '🇵🇾',
    'QAR': '🇶🇦',
    'RON': '🇷🇴',
    'RSD': '🇷🇸',
    'RUB': '🇷🇺',
    'RWF': '🇷🇼',
    'SAR': '🇸🇦',
    'SBD': '🇸🇧',
    'SCR': '🇸🇨',
    'SDG': '🇸🇩',
    'SEK': '🇸🇪',
    'SGD': '🇸🇬',
    'SHP': '🇸🇭',
    'SLL': '🇸🇱',
    'SOS': '🇸🇴',
    'SRD': '🇸🇷',
    'STD': '🇸🇹',
    'SVC': '🇸🇻',
    'SYP': '🇸🇾',
    'SZL': '🇸🇿',
    'THB': '🇹🇭',
    'TJS': '🇹🇯',
    'TMT': '🇹🇲',
    'TND': '🇹🇳',
    'TOP': '🇹🇴',
    'TRY': '🇹🇷',
    'TTD': '🇹🇹',
    'TWD': '🇹🇼',
    'TZS': '🇹🇿',
    'UAH': '🇺🇦',
    'UGX': '🇺🇬',
    'USD': '🇺🇸',
    'UYU': '🇺🇾',
    'UZS': '🇺🇿',
    'VEF': '🇻🇪',
    'VND': '🇻🇳',
    'VUV': '🇻🇺',
    'WST': '🇼🇸',
    'XAF': '🇨🇲', // picked Cameroon among BEAC members
    'XAG': '⚪',
    'XAU': '🟡',
    'XCD': '🇰🇳', // East Caribbean Dollar (choosing St. Kitts & Nevis)
    'XOF': '🇸🇳', // picked Senegal among BCEAO members
    'XPF': '🇵🇫',
    'YER': '🇾🇪',
    'ZAR': '🇿🇦',
    // 'ZMK': no longer used
    'ZMW': '🇿🇲',
    'ZWL': '🇿🇼',
  };

  /// Currency code → full display name.
  ///
  /// Used in pickers and other UI to show a human-friendly description.
  static final Map<String, String> _names = {
    'AED': 'United Arab Emirates Dirham',
    'AFN': 'Afghan Afghani',
    'ALL': 'Albanian Lek',
    'AMD': 'Armenian Dram',
    'ANG': 'Netherlands Antillean Guilder',
    'AOA': 'Angolan Kwanza',
    'ARS': 'Argentine Peso',
    'AUD': 'Australian Dollar',
    'AWG': 'Aruban Florin',
    'AZN': 'Azerbaijani Manat',
    'BAM': 'Bosnia-Herzegovina Convertible Mark',
    'BBD': 'Barbadian Dollar',
    'BDT': 'Bangladeshi Taka',
    'BGN': 'Bulgarian Lev',
    'BHD': 'Bahraini Dinar',
    'BIF': 'Burundian Franc',
    'BMD': 'Bermudan Dollar',
    'BND': 'Brunei Dollar',
    'BOB': 'Bolivian Boliviano',
    'BRL': 'Brazilian Real',
    'BSD': 'Bahamian Dollar',
    'BTC': 'Bitcoin',
    'BTN': 'Bhutanese Ngultrum',
    'BWP': 'Botswanan Pula',
    'BYN': 'New Belarusian Ruble',
    'BYR': 'Belarusian Ruble',
    'BZD': 'Belize Dollar',
    'CAD': 'Canadian Dollar',
    'CDF': 'Congolese Franc',
    'CHF': 'Swiss Franc',
    'CLF': 'Chilean Unit of Account (UF)',
    'CLP': 'Chilean Peso',
    'CNY': 'Chinese Yuan',
    'COP': 'Colombian Peso',
    'CRC': 'Costa Rican Colón',
    'CUC': 'Cuban Convertible Peso',
    'CUP': 'Cuban Peso',
    'CVE': 'Cape Verdean Escudo',
    'CZK': 'Czech Republic Koruna',
    'DJF': 'Djiboutian Franc',
    'DKK': 'Danish Krone',
    'DOP': 'Dominican Peso',
    'DZD': 'Algerian Dinar',
    'EGP': 'Egyptian Pound',
    'ERN': 'Eritrean Nakfa',
    'ETB': 'Ethiopian Birr',
    'EUR': 'Euro',
    'FJD': 'Fijian Dollar',
    'FKP': 'Falkland Islands Pound',
    'GBP': 'British Pound Sterling',
    'GEL': 'Georgian Lari',
    'GGP': 'Guernsey Pound',
    'GHS': 'Ghanaian Cedi',
    'GIP': 'Gibraltar Pound',
    'GMD': 'Gambian Dalasi',
    'GNF': 'Guinean Franc',
    'GTQ': 'Guatemalan Quetzal',
    'GYD': 'Guyanaese Dollar',
    'HKD': 'Hong Kong Dollar',
    'HNL': 'Honduran Lempira',
    'HRK': 'Croatian Kuna',
    'HTG': 'Haitian Gourde',
    'HUF': 'Hungarian Forint',
    'IDR': 'Indonesian Rupiah',
    'ILS': 'Israeli New Sheqel',
    'IMP': 'Manx Pound',
    'INR': 'Indian Rupee',
    'IQD': 'Iraqi Dinar',
    'IRR': 'Iranian Rial',
    'ISK': 'Icelandic Króna',
    'JEP': 'Jersey Pound',
    'JMD': 'Jamaican Dollar',
    'JOD': 'Jordanian Dinar',
    'JPY': 'Japanese Yen',
    'KES': 'Kenyan Shilling',
    'KGS': 'Kyrgystani Som',
    'KHR': 'Cambodian Riel',
    'KMF': 'Comorian Franc',
    'KPW': 'North Korean Won',
    'KRW': 'South Korean Won',
    'KWD': 'Kuwaiti Dinar',
    'KYD': 'Cayman Islands Dollar',
    'KZT': 'Kazakhstani Tenge',
    'LAK': 'Laotian Kip',
    'LBP': 'Lebanese Pound',
    'LKR': 'Sri Lankan Rupee',
    'LRD': 'Liberian Dollar',
    'LSL': 'Lesotho Loti',
    'LTL': 'Lithuanian Litas',
    'LVL': 'Latvian Lats',
    'LYD': 'Libyan Dinar',
    'MAD': 'Moroccan Dirham',
    'MDL': 'Moldovan Leu',
    'MGA': 'Malagasy Ariary',
    'MKD': 'Macedonian Denar',
    'MMK': 'Myanma Kyat',
    'MNT': 'Mongolian Tugrik',
    'MOP': 'Macanese Pataca',
    'MRO': 'Mauritanian Ouguiya',
    'MUR': 'Mauritian Rupee',
    'MVR': 'Maldivian Rufiyaa',
    'MWK': 'Malawian Kwacha',
    'MXN': 'Mexican Peso',
    'MYR': 'Malaysian Ringgit',
    'MZN': 'Mozambican Metical',
    'NAD': 'Namibian Dollar',
    'NGN': 'Nigerian Naira',
    'NIO': 'Nicaraguan Córdoba',
    'NOK': 'Norwegian Krone',
    'NPR': 'Nepalese Rupee',
    'NZD': 'New Zealand Dollar',
    'OMR': 'Omani Rial',
    'PAB': 'Panamanian Balboa',
    'PEN': 'Peruvian Nuevo Sol',
    'PGK': 'Papua New Guinean Kina',
    'PHP': 'Philippine Peso',
    'PKR': 'Pakistani Rupee',
    'PLN': 'Polish Zloty',
    'PYG': 'Paraguayan Guarani',
    'QAR': 'Qatari Rial',
    'RON': 'Romanian Leu',
    'RSD': 'Serbian Dinar',
    'RUB': 'Russian Ruble',
    'RWF': 'Rwandan Franc',
    'SAR': 'Saudi Riyal',
    'SBD': 'Solomon Islands Dollar',
    'SCR': 'Seychellois Rupee',
    'SDG': 'Sudanese Pound',
    'SEK': 'Swedish Krona',
    'SGD': 'Singapore Dollar',
    'SHP': 'Saint Helena Pound',
    'SLL': 'Sierra Leonean Leone',
    'SOS': 'Somali Shilling',
    'SRD': 'Surinamese Dollar',
    'STD': 'São Tomé and Príncipe Dobra',
    'SVC': 'Salvadoran Colón',
    'SYP': 'Syrian Pound',
    'SZL': 'Swazi Lilangeni',
    'THB': 'Thai Baht',
    'TJS': 'Tajikistani Somoni',
    'TMT': 'Turkmenistani Manat',
    'TND': 'Tunisian Dinar',
    'TOP': 'Tongan Pa`anga',
    'TRY': 'Turkish Lira',
    'TTD': 'Trinidad and Tobago Dollar',
    'TWD': 'New Taiwan Dollar',
    'TZS': 'Tanzanian Shilling',
    'UAH': 'Ukrainian Hryvnia',
    'UGX': 'Ugandan Shilling',
    'USD': 'United States Dollar',
    'UYU': 'Uruguayan Peso',
    'UZS': 'Uzbekistan Som',
    'VEF': 'Venezuelan Bolívar Fuerte',
    'VND': 'Vietnamese Dong',
    'VUV': 'Vanuatu Vatu',
    'WST': 'Samoan Tala',
    'XAF': 'CFA Franc BEAC',
    'XAG': 'Silver (troy ounce)',
    'XAU': 'Gold (troy ounce)',
    'XCD': 'East Caribbean Dollar',
    'XDR': 'Special Drawing Rights',
    'XOF': 'CFA Franc BCEAO',
    'XPF': 'CFP Franc',
    'YER': 'Yemeni Rial',
    'ZAR': 'South African Rand',
    'ZMK': 'Zambian Kwacha (pre-2013)',
    'ZMW': 'Zambian Kwacha',
    'ZWL': 'Zimbabwean Dollar',
  };

  // --------------- public getters ---------------

  /// Exposes the currently generated mock rates (read-only).
  static Map<String, double> get mockRates => _mockRates;

  /// Returns the timestamp of the last successful live sync, if any.
  static DateTime? get lastSync => _lastSync;

  // --------------- internal helpers ---------------

  /// Builds a deterministic mock rate table based on [_allCodes].
  ///
  /// Sorted alphabetically and then assigned incremental values:
  /// 1.00, 1.01, 1.02, ...
  static Map<String, double> _buildMockRates() {
    final sorted = _allCodes.toList()..sort();
    final map = <String, double>{};
    for (var i = 0; i < sorted.length; i++) {
      map[sorted[i]] = 1.0 + 0.01 * i;
    }
    return Map.unmodifiable(map);
  }

  // --------------- public API ---------------

  /// Loads the last sync timestamp from persistent storage.
  ///
  /// Should be called on app startup or before displaying sync info.
  static Future<void> loadLastSync() async {
    _lastSync = await SettingsManager.loadLastSync();
  }

  /// Returns either mock or live rates, depending on [useMock].
  ///
  /// - When [useMock] is `true`, returns [_mockRates].
  /// - When [useMock] is `false`, returns [_liveRates] if present,
  ///   otherwise falls back to [_mockRates].
  static Map<String, double> getRates(bool useMock) {
    if (useMock) return _mockRates;
    return _liveRates ?? _mockRates;
  }

  /// Returns all currency codes for the currently available rates.
  ///
  /// The result is sorted alphabetically for stable UI presentation.
  static List<String> getCurrencyCodes(bool useMock) {
    final rates = getRates(useMock);
    final codes = rates.keys.toList()..sort();
    return codes;
  }

  /// Fetches latest live rates from the API and updates internal state.
  ///
  /// - Updates [_liveRates] with fresh data.
  /// - Extends [_allCodes] and regenerates [_mockRates] so that
  ///   mock mode stays in sync with new currencies.
  /// - Stores [_lastSync] via [SettingsManager.saveLastSync].
  ///
  /// Returns the fetched live rate map.
  static Future<Map<String, double>> syncLiveRates() async {
    final fetched = await ExchangeRatesService.fetchLatestRates();

    // Track all codes we've seen from the API.
    _allCodes.addAll(fetched.keys);

    _liveRates = fetched;
    _mockRates = _buildMockRates();

    _lastSync = DateTime.now();
    await SettingsManager.saveLastSync(_lastSync!);

    return fetched;
  }

  /// Fetches historical cross rates for [base] → [quote] for the last [days] days.
  ///
  /// Behaviour:
  /// - If mock mode is enabled, returns synthetic data derived from mock rates
  ///   without any network calls.
  /// - If live mode is enabled, delegates to the exchangeratesapi.io
  ///   historical endpoint via [ExchangeRatesService.fetchHistoricalRates].
  ///
  /// Throws:
  /// - [ArgumentError] when [days] is less than 1.
  static Future<List<HistoryPoint>> fetchHistoricalRates({
    required String base,
    required String quote,
    int days = 5,
  }) async {
    if (days < 1) {
      throw ArgumentError.value(days, 'days', 'must be >= 1');
    }

    final useMock = await SettingsManager.loadUseMockRates();

    // MOCK MODE → generate simple synthetic history.
    if (useMock) {
      final rates = getRates(true);
      final baseRate = rates[base] ?? 1.0;
      final quoteRate = rates[quote] ?? 1.0;
      final cross = quoteRate / baseRate;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final result = <HistoryPoint>[];

      // Create slight variation for each mock day around the center.
      for (int i = days - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final centeredIndex = i - (days - 1) / 2;
        final factor = 1.0 + centeredIndex * 0.003;
        result.add(
          HistoryPoint(date: date, rate: cross * factor),
        );
      }
      return result;
    }

    // LIVE MODE → use service historical endpoint.
    final raw = await ExchangeRatesService.fetchHistoricalRates(
      base: base,
      quote: quote,
      days: days,
    );

    final dates = raw.keys.toList()..sort();
    final result = <HistoryPoint>[];

    for (final d in dates) {
      final dayRates = raw[d]!;
      final baseRate = dayRates[base];
      final quoteRate = dayRates[quote];
      if (baseRate == null || quoteRate == null) {
        // Skip days where either base or quote is not present.
        continue;
      }
      final cross = quoteRate / baseRate;
      result.add(HistoryPoint(date: d, rate: cross));
    }

    return result;
  }

  /// Returns the flag emoji for [code], or a white flag as fallback.
  static String flagFor(String code) {
    return _flags[code] ?? '🏳️';
  }

  /// Returns the human-readable display name for [code], or the code itself
  /// when no mapping is available.
  static String nameFor(String code) {
    return _names[code] ?? code;
  }
}
