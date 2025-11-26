// -----------------------------------------------------------------------------
// currentcy – Single Conversion Screen
//
// This file contains:
// - The [SingleConv] widget (stateful)
// - UI and logic for converting between two currencies
// - Currency picker with favorites and search
// - Synchronization trigger for live exchange rates
//
// Responsibilities:
// - Load rates and user settings (mock mode, favorites)
// - Perform one-direction currency conversion (left -> right)
// - Allow changing currencies via a searchable bottom sheet
// - Show last synchronization status and sync action
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

/// Single currency conversion screen.
///
/// Allows the user to enter an amount in the "from" currency and see
/// the converted amount in the "to" currency using the current rates.
class SingleConv extends StatefulWidget {
  const SingleConv({super.key});

  @override
  State<SingleConv> createState() => _SingleConvState();
}

class _SingleConvState extends State<SingleConv> {
  /// Text controller for the input (left) amount.
  final TextEditingController fromController =
      TextEditingController(text: '12.50');

  /// Text controller for the output (right) amount.
  final TextEditingController toController =
      TextEditingController(text: '13.38');

  /// Currently loaded exchange rates mapped by currency code.
  Map<String, double> _rates = {};

  /// All available currency codes for selection.
  List<String> _currencyOptions = [];

  /// List of user favorite currencies (subset of [_currencyOptions]).
  List<String> _favoriteCurrencies = [];

  /// Currently selected "from" currency code.
  String fromCurrency = 'CHF';

  /// Currently selected "to" currency code.
  String toCurrency = 'EUR';

  /// True while a live synchronization is in progress.
  bool _isSyncing = false;

  /// Whether mock rates are being used instead of live data.
  bool _useMockRates = true;

  /// Whether initial settings and rates are still loading.
  bool _isLoading = true;

  /// Timestamp of the last successful synchronization (live data).
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    // Whenever the input amount changes, recalculate the converted value.
    fromController.addListener(_onFromAmountChanged);
    _initSettingsAndRates();
  }

  /// Loads settings and initial rates, then prepares the UI state.
  ///
  /// - Reads `useMockRates` from settings.
  /// - Loads last sync timestamp and rates from [CurrencyRepository].
  /// - Validates and normalizes favorites and current from/to currencies.
  Future<void> _initSettingsAndRates() async {
    final useMock = await SettingsManager.loadUseMockRates();
    await CurrencyRepository.loadLastSync();

    final rates = CurrencyRepository.getRates(useMock);
    final options = CurrencyRepository.getCurrencyCodes(useMock);

    // Load favorites and keep only those that exist in the current options.
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final validFavs = favs.where((c) => options.contains(c)).toList();

    String newFrom = fromCurrency;
    String newTo = toCurrency;

    // Fallback to first available currencies if the stored ones are invalid.
    if (!options.contains(newFrom) && options.isNotEmpty) {
      newFrom = options.first;
    }
    if (!options.contains(newTo) && options.length > 1) {
      newTo = options[1];
    }

    setState(() {
      _useMockRates = useMock;
      _rates = rates;
      _currencyOptions = options;
      _favoriteCurrencies = validFavs;
      fromCurrency = newFrom;
      toCurrency = newTo;
      _lastSync = CurrencyRepository.lastSync;
      _isLoading = false;
    });

    _onFromAmountChanged();
  }

  @override
  void dispose() {
    fromController.removeListener(_onFromAmountChanged);
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  /// Handles changes in the "from" amount and updates the "to" amount.
  ///
  /// - Accepts both comma and dot as decimal separators.
  /// - Clears the output if the input cannot be parsed.
  void _onFromAmountChanged() {
    final text = fromController.text.replaceAll(',', '.');
    final value = double.tryParse(text);

    if (value == null) {
      setState(() => toController.text = '');
      return;
    }

    final rate = _getRate(fromCurrency, toCurrency);
    final converted = value * rate;
    toController.text = converted.toStringAsFixed(2);
  }

  /// Returns the conversion rate between [from] and [to].
  ///
  /// If a rate is missing, it falls back to 1.0 for that currency.
  /// The returned value represents: 1 [from] = X [to].
  double _getRate(String from, String to) {
    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;
    return toRate / fromRate;
  }

  /// Swaps the "from" and "to" currencies and their respective amounts.
  ///
  /// After swapping, the conversion is recalculated to ensure consistency.
  void _swapCurrencies() {
    setState(() {
      final oldFrom = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = oldFrom;

      final oldFromText = fromController.text;
      fromController.text = toController.text;
      toController.text = oldFromText;
    });

    _onFromAmountChanged();
  }

  /// Handles tap on the "synchronize now" button.
  ///
  /// - Shows an info message when mock mode is active.
  /// - Otherwise, triggers a live rates sync via [CurrencyRepository.syncLiveRates].
  /// - Updates available currency options and last sync timestamp.
  Future<void> _onSynchronizePressed() async {
    if (_useMockRates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mock mode is enabled. Disable it in Settings to fetch live rates.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final newRates = await CurrencyRepository.syncLiveRates();
      final options = CurrencyRepository.getCurrencyCodes(false);

      // Ensure selected currencies remain valid after sync.
      if (!options.contains(fromCurrency)) {
        fromCurrency = options.first;
      }
      if (!options.contains(toCurrency) && options.length > 1) {
        toCurrency = options[1];
      }

      setState(() {
        _rates = newRates;
        _currencyOptions = options;
        _lastSync = CurrencyRepository.lastSync;
      });

      _onFromAmountChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update rates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Opens a modal bottom sheet to choose a currency.
  ///
  /// - Displays favorites at the top, followed by all other currencies.
  /// - Provides a search field for code and name.
  /// - When a currency is selected, updates either [fromCurrency] or
  ///   [toCurrency] depending on [isFrom].
  Future<void> _showCurrencyPicker({required bool isFrom}) async {
    if (_currencyOptions.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();

        // Prepare base lists for favorites and other currencies.
        List<String> favBase = _favoriteCurrencies
            .where((c) => _currencyOptions.contains(c))
            .toList();
        List<String> othersBase = _currencyOptions
            .where((c) => !favBase.contains(c))
            .toList();

        // These lists will be filtered in-place by the search logic.
        List<String> favFiltered = List.of(favBase);
        List<String> othersFiltered = List.of(othersBase);

        void applyFilter(String q) {
          final query = q.toLowerCase();
          if (query.isEmpty) {
            favFiltered = List.of(favBase);
            othersFiltered = List.of(othersBase);
          } else {
            bool matches(String code) {
              final name =
                  CurrencyRepository.nameFor(code).toLowerCase();
              return code.toLowerCase().contains(query) ||
                  name.contains(query);
            }

            favFiltered = favBase.where(matches).toList();
            othersFiltered = othersBase.where(matches).toList();
          }
        }

        // Initial filter with empty query.
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
                builder: (context, setModalState) {
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
                          margin: const EdgeInsets.only(
                            top: 8,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Search field.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            8,
                          ),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:
                                  'Search currency (code or name)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                applyFilter(value);
                              });
                            },
                          ),
                        ),

                        // List of favorites and all other currencies.
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (favFiltered.isNotEmpty) ...[
                                ...favFiltered.map((code) {
                                  final flag =
                                      CurrencyRepository.flagFor(code);
                                  final name =
                                      CurrencyRepository.nameFor(code);
                                  return ListTile(
                                    leading: Text(
                                      flag,
                                      style: const TextStyle(
                                        fontSize: 28,
                                      ),
                                    ),
                                    title: Text(name),
                                    subtitle: Text(code),
                                    trailing: const Text(
                                      '☆',
                                      style: TextStyle(
                                        fontSize: 20,
                                      ),
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(code),
                                  );
                                }),
                                const Divider(),
                              ],
                              ...othersFiltered.map((code) {
                                final flag =
                                    CurrencyRepository.flagFor(code);
                                final name =
                                    CurrencyRepository.nameFor(code);
                                return ListTile(
                                  leading: Text(
                                    flag,
                                    style: const TextStyle(
                                      fontSize: 28,
                                    ),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(code),
                                  onTap: () =>
                                      Navigator.of(context).pop(code),
                                );
                              }),
                            ],
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
        if (isFrom) {
          fromCurrency = selected;
        } else {
          toCurrency = selected;
        }
      });
      _onFromAmountChanged();
    }
  }

  /// Shows an info message when the user taps on the right (output) field.
  ///
  /// The right box is read-only, so this guides the user to edit the left box.
  void _onRightButtonPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your input into the left box.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Builds user-facing text describing the last synchronization state.
  ///
  /// Handles:
  /// - Mock mode notice
  /// - "never synchronized" case
  /// - Human-readable timestamp of the last sync
  String _formatLastSyncText() {
    if (_useMockRates) {
      return 'Mock mode is enabled. Go to Settings to disable it and fetch live exchange rates.';
    }

    if (_lastSync == null) {
      return 'Last synchronization: never\nTap "synchronize now" to fetch the newest rates.';
    }

    final d = _lastSync!;
    final t =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return 'Last synchronization: $t\nTap "synchronize now" to refresh the exchange rates.';
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading state while settings and rates are fetched.
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final rateText =
        '1 $fromCurrency = ${_getRate(fromCurrency, toCurrency).toStringAsFixed(6)} $toCurrency';

    final fromName = CurrencyRepository.nameFor(fromCurrency);
    final toName = CurrencyRepository.nameFor(toCurrency);

    return Scaffold(
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Convert currency',
              style:
                  TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            const Text(
              'Tap on the fields below to change the amount and currency.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // ---- Amount fields row ----
            Row(
              children: [
                // Left (input) amount.
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border:
                          Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: fromController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      decoration:
                          const InputDecoration.collapsed(
                              hintText: ''),
                    ),
                  ),
                ),

                // Swap button between fields.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz,
                            size: 36),
                        onPressed: _swapCurrencies,
                      ),
                      const Text('swap',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

                // Right (output) amount.
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(28),
                      border:
                          Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: toController,
                      readOnly: true,
                      onTap: _onRightButtonPressed,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      decoration:
                          const InputDecoration.collapsed(
                              hintText: ''),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ---- Currency selection row ----
            Row(
              children: [
                // From currency selector.
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _showCurrencyPicker(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fromCurrency,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  fromName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyRepository.flagFor(
                                fromCurrency),
                            style: const TextStyle(
                                fontSize: 26,
                                color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // To currency selector.
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _showCurrencyPicker(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyRepository.flagFor(toCurrency),
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  toCurrency,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  softWrap: false,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  toName,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  softWrap: false,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // ---- Rate information ----
            Center(
              child: Text(
                rateText,
                style: const TextStyle(fontSize: 13),
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),

      // ---- Bottom sync area ----
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Synchronize / mock mode button.
            ElevatedButton(
              onPressed:
                  _isSyncing ? null : _onSynchronizePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _useMockRates
                    ? Colors.grey[400]
                    : Colors.yellow[700],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(30)),
                elevation: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _useMockRates
                        ? 'mock mode active'
                        : (_isSyncing
                            ? 'synchronizing...'
                            : 'synchronize now'),
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Last sync info text.
            Text(
              _formatLastSyncText(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
