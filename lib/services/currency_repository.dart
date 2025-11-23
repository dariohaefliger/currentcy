import 'package:currentcy/services/exchange_rates_service.dart';
import 'package:currentcy/settings/settings_manager.dart';

class CurrencyRepository {
  /// Base set of supported currency codes BEFORE FIRST SYNC
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

  /// All known codes = base codes + codes we’ve seen from the API.
  static final Set<String> _allCodes = {..._baseCodes};

  /// Mock rates; built from _allCodes in alphabetical order:
  /// 1.00, 1.01, 1.02, ...
  static Map<String, double> _mockRates = _buildMockRates();

  /// Live rates from API (EUR-based free plan).
  static Map<String, double>? _liveRates;

  /// Last sync time (live rates).
  static DateTime? _lastSync;

  /// Currency -> flag emoji.
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


  /// Currency -> full name.
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

  static Map<String, double> get mockRates => _mockRates;

  static DateTime? get lastSync => _lastSync;

  // --------------- internal helpers ---------------

  static Map<String, double> _buildMockRates() {
    final sorted = _allCodes.toList()..sort();
    final map = <String, double>{};
    for (var i = 0; i < sorted.length; i++) {
      map[sorted[i]] = 1.0 + 0.01 * i;
    }
    return Map.unmodifiable(map);
  }

  // --------------- public API ---------------

  static Future<void> loadLastSync() async {
    _lastSync = await SettingsManager.loadLastSync();
  }

  static Map<String, double> getRates(bool useMock) {
    if (useMock) return _mockRates;
    return _liveRates ?? _mockRates;
  }

  static List<String> getCurrencyCodes(bool useMock) {
    final rates = getRates(useMock);
    final codes = rates.keys.toList()..sort();
    return codes;
  }

  static Future<Map<String, double>> syncLiveRates() async {
    final fetched = await ExchangeRatesService.fetchLatestRates();

    _allCodes.addAll(fetched.keys);

    _liveRates = fetched;
    _mockRates = _buildMockRates();

    _lastSync = DateTime.now();
    await SettingsManager.saveLastSync(_lastSync!);

    return fetched;
  }

  static String flagFor(String code) {
    return _flags[code] ?? '🏳️';
  }

  static String nameFor(String code) {
    return _names[code] ?? code;
  }
}
