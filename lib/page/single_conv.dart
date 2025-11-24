import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

class SingleConv extends StatefulWidget {
  const SingleConv({super.key});

  @override
  State<SingleConv> createState() => _SingleConvState();
}

class _SingleConvState extends State<SingleConv> {
  final TextEditingController fromController =
      TextEditingController(text: '12.50');
  final TextEditingController toController =
      TextEditingController(text: '13.38');

  Map<String, double> _rates = {};
  List<String> _currencyOptions = [];

  // favourites (codes) for the picker
  List<String> _favoriteCurrencies = [];

  String fromCurrency = 'CHF';
  String toCurrency = 'EUR';

  bool _isSyncing = false;
  bool _useMockRates = true;
  bool _isLoading = true;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    fromController.addListener(_onFromAmountChanged);
    _initSettingsAndRates();
  }

  Future<void> _initSettingsAndRates() async {
    final useMock = await SettingsManager.loadUseMockRates();
    await CurrencyRepository.loadLastSync();

    final rates = CurrencyRepository.getRates(useMock);
    final options = CurrencyRepository.getCurrencyCodes(useMock);

    // load favourites
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final validFavs =
        favs.where((c) => options.contains(c)).toList();

    String newFrom = fromCurrency;
    String newTo = toCurrency;

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

  // --------------------------
  // CONVERSION
  // --------------------------

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

  double _getRate(String from, String to) {
    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;
    return toRate / fromRate;
  }

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

  // --------------------------
  // SYNC
  // --------------------------

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

  // --------------------------
  // SEARCHABLE PICKER
  // --------------------------

  Future<void> _showCurrencyPicker({required bool isFrom}) async {
    if (_currencyOptions.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();

        // base lists
        List<String> favBase = _favoriteCurrencies
            .where((c) => _currencyOptions.contains(c))
            .toList();
        List<String> othersBase = _currencyOptions
            .where((c) => !favBase.contains(c))
            .toList();

        // filtered lists
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

            favFiltered =
                favBase.where(matches).toList();
            othersFiltered =
                othersBase.where(matches).toList();
          }
        }

        // initial state without filter
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
                        // Grabber
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(
                              top: 8, bottom: 12),
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
                              setModalState(() {
                                applyFilter(value);
                              });
                            },
                          ),
                        ),

                        // Favs + Divider + Others as one list
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
                                          fontSize: 28),
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
                                        Navigator.of(context)
                                            .pop(code),
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
                                        fontSize: 28),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(code),
                                  onTap: () =>
                                      Navigator.of(context)
                                          .pop(code),
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

  // --------------------------
  // UI HELPERS
  // --------------------------

  void _onRightButtonPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your input into the left box.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

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

            // INPUT ROWS
            Row(
              children: [
                // INPUT LEFT
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

                // SWAP BUTTON
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

                // OUTPUT RIGHT
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          const Color.fromARGB(255, 116, 115, 115),
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

            // CURRENCY PICKERS
            Row(
              children: [
                // FROM currency
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

                // TO currency
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
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  toCurrency,
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
                                  toName,
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
                                toCurrency),
                            style: const TextStyle(
                                fontSize: 26,
                                color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

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

      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
