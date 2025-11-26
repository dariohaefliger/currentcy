// -----------------------------------------------------------------------------
// currentcy – Multi Conversion Screen
//
// This file contains:
// - The [MultiConv] widget (stateful)
// - Logic for converting one base amount into multiple currencies
// - Currency picker with favourites and search
// - Synchronization trigger for live exchange rates
//
// Responsibilities:
// - Load rates and user settings (mock mode, favourites)
// - Convert a single input amount into several target currencies
// - Support rotating currencies & amounts for quick reordering
// - Show last synchronization status and sync action
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

/// Multi currency conversion screen.
///
/// Allows the user to enter an amount in one base currency and see the
/// converted values for multiple other currencies in parallel.
class MultiConv extends StatefulWidget {
  const MultiConv({super.key});

  @override
  State<MultiConv> createState() => _MultiConvState();
}

class _MultiConvState extends State<MultiConv>
    with SingleTickerProviderStateMixin {
  /// Text controllers for the four rows (row 0 is the editable base amount).
  late List<TextEditingController> controllers;

  /// Currency code for each row (length must match [controllers]).
  late List<String> currencies;

  /// Currently loaded exchange rates mapped by currency code.
  Map<String, double> _rates = {};

  /// All available currency codes for selection.
  List<String> _currencyOptions = [];

  /// Favourite currency codes used to highlight options in the picker.
  List<String> _favoriteCurrencies = [];

  /// Controls the rotation animation for the rotate button.
  late AnimationController _rotationController;

  /// Whether mock rates are being used instead of live data.
  bool _useMockRates = true;

  /// True while a live synchronization is in progress.
  bool _isSyncing = false;

  /// Whether initial settings and rates are still loading.
  bool _isLoading = true;

  /// Timestamp of the last successful synchronization (live data).
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();

    // Default initial currencies for the four rows.
    currencies = ['CHF', 'EUR', 'USD', 'GBP'];

    // Create one controller per row; row 0 is editable input.
    controllers = List.generate(4, (index) => TextEditingController());
    controllers[0].text = '100.00';

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Whenever the main input changes, recalculate all other rows.
    controllers[0].addListener(_recalculateFromMain);

    _initSettingsAndRates();
  }

  /// Loads settings and initial rates, then prepares the UI state.
  ///
  /// - Reads `useMockRates` from settings.
  /// - Loads last sync timestamp and rates from [CurrencyRepository].
  /// - Validates and normalizes favourites and the current currencies list.
  Future<void> _initSettingsAndRates() async {
    final useMock = await SettingsManager.loadUseMockRates();
    await CurrencyRepository.loadLastSync();

    final rates = CurrencyRepository.getRates(useMock);
    final options = CurrencyRepository.getCurrencyCodes(useMock);

    // Load favorites and keep only those that exist in the current options.
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final validFavs = favs.where((c) => options.contains(c)).toList();

    // Ensure that each row has a valid currency, falling back to available ones.
    final fixedCurrencies = <String>[];
    for (var i = 0; i < currencies.length; i++) {
      final code = currencies[i];
      if (options.contains(code)) {
        fixedCurrencies.add(code);
      } else if (options.isNotEmpty) {
        fixedCurrencies.add(options[i < options.length ? i : 0]);
      } else {
        fixedCurrencies.add(code);
      }
    }

    setState(() {
      _useMockRates = useMock;
      _rates = rates;
      _currencyOptions = options;
      _favoriteCurrencies = validFavs;
      currencies = fixedCurrencies;
      _lastSync = CurrencyRepository.lastSync;
      _isLoading = false;
    });

    _recalculateFromMain();
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    _rotationController.dispose();
    super.dispose();
  }

  // ---- conversion logic ----

  /// Returns the conversion rate between [from] and [to].
  ///
  /// If a rate is missing, it falls back to 1.0 for that currency.
  /// The returned value represents: 1 [from] = X [to].
  double _rate(String from, String to) {
    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;
    return toRate / fromRate;
  }

  /// Recalculates all dependent rows based on the main (row 0) amount.
  ///
  /// - Parses the main input as a double (supports comma as decimal separator).
  /// - Clears other rows when parsing fails.
  /// - Updates rows 1–3 using the current base currency from row 0.
  void _recalculateFromMain() {
    final txt = controllers[0].text.replaceAll(',', '.');
    final value = double.tryParse(txt);

    if (value == null) {
      for (int i = 1; i < controllers.length; i++) {
        controllers[i].text = '';
      }
      setState(() {});
      return;
    }

    final baseCurrency = currencies[0];
    for (int i = 1; i < currencies.length; i++) {
      final r = _rate(baseCurrency, currencies[i]);
      controllers[i].text = (value * r).toStringAsFixed(2);
    }
    setState(() {});
  }

  /// Updates the currency at [index] and recalculates all rows.
  void _onCurrencyChanged(int index, String newCode) {
    setState(() {
      currencies[index] = newCode;
    });
    _recalculateFromMain();
  }

  /// Rotates the list of currencies and amounts clockwise.
  ///
  /// - Plays a rotation animation on the refresh icon.
  /// - Moves the last currency to the first position.
  /// - Shifts the corresponding amounts in the same order.
  void _rotateClockwise() async {
    await _rotationController.forward(from: 0.0);

    setState(() {
      final lastCurrency = currencies.removeLast();
      currencies.insert(0, lastCurrency);

      final lastText = controllers.last.text;
      for (int i = controllers.length - 1; i > 0; i--) {
        controllers[i].text = controllers[i - 1].text;
      }
      controllers[0].text = lastText;
    });

    _recalculateFromMain();
  }

  // ---- sync ----

  /// Handles tap on the "synchronize now" button.
  ///
  /// - Shows an info message when mock mode is active.
  /// - Otherwise, triggers a live rates sync via [CurrencyRepository.syncLiveRates].
  /// - Ensures all row currencies remain valid after the sync.
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

    setState(() {
      _isSyncing = true;
    });

    try {
      final newRates = await CurrencyRepository.syncLiveRates();
      final options = CurrencyRepository.getCurrencyCodes(false);

      // Normalize current currencies against the newly available options.
      final fixedCurrencies = <String>[];
      for (var i = 0; i < currencies.length; i++) {
        final code = currencies[i];
        if (options.contains(code)) {
          fixedCurrencies.add(code);
        } else if (options.isNotEmpty) {
          fixedCurrencies.add(options[i < options.length ? i : 0]);
        } else {
          fixedCurrencies.add(code);
        }
      }

      setState(() {
        _rates = newRates;
        _currencyOptions = options;
        currencies = fixedCurrencies;
        _lastSync = CurrencyRepository.lastSync;
      });

      _recalculateFromMain();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update rates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ---- currency picker with search + favourites ----

  /// Opens a modal bottom sheet to choose a currency for row [index].
  ///
  /// - Displays favourites at the top, followed by all other currencies.
  /// - Provides a search field for code and name.
  /// - Updates the currency for the given index on selection.
  Future<void> _showCurrencyPicker(int index) async {
    if (_currencyOptions.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();

        // Prepare base lists for favourites and other currencies.
        List<String> favBase = _favoriteCurrencies
            .where((c) => _currencyOptions.contains(c))
            .toList();
        List<String> othersBase = _currencyOptions
            .where((c) => !favBase.contains(c))
            .toList();

        // These lists will be filtered in-place by the search logic.
        List<String> favFiltered = List.of(favBase);
        List<String> othersFiltered = List.of(othersBase);

        void applyFilter(String query) {
          final q = query.toLowerCase();
          if (q.isEmpty) {
            favFiltered = List.of(favBase);
            othersFiltered = List.of(othersBase);
          } else {
            bool matches(String code) {
              final name =
                  CurrencyRepository.nameFor(code).toLowerCase();
              return code.toLowerCase().contains(q) ||
                  name.contains(q);
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

                        // List of favourites and all other currencies.
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
      _onCurrencyChanged(index, selected);
    }
  }

  /// Convenience wrapper for flag lookup by [code].
  String _flagFor(String code) => CurrencyRepository.flagFor(code);

  /// Convenience wrapper for name lookup by [code].
  String _nameFor(String code) => CurrencyRepository.nameFor(code);

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
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return 'Last synchronization: $dateStr\nTap "synchronize now" to refresh the exchange rates.';
  }

  // ---- UI helpers ----

  /// Builds the main editable input field (row 0).
  Widget _buildMainField() {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: TextField(
          controller: controllers[0],
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }

  /// Builds a read-only field for derived rows (rows 1–3).
  Widget _buildDisabledField(int idx) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: TextField(
          controller: controllers[idx],
          readOnly: true,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }

  /// Builds a currency "chip" for the given [index].
  ///
  /// Shows code, full name and flag, and opens the currency picker on tap.
  Widget _buildCurrencyChip(int index) {
    final code = currencies[index];
    final flag = _flagFor(code);
    final name = _nameFor(code);

    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _showCurrencyPicker(index),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ],
                ),
              ),
              Text(
                flag,
                style:
                    const TextStyle(fontSize: 20, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a row with amount field and currency chip.
  ///
  /// When [editable] is true, the amount is user-editable (row 0),
  /// otherwise it is read-only (rows 1–3).
  Widget _buildRow(int index, {required bool editable}) {
    return Row(
      children: [
        editable ? _buildMainField() : _buildDisabledField(index),
        const SizedBox(width: 12),
        _buildCurrencyChip(index),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading state while settings and rates are fetched.
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Multi Conversion',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edit the top amount. Pick currencies for each row. Use the rotate button to rotate currencies & amounts.',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 20),

              // Main editable row.
              _buildRow(0, editable: true),
              const SizedBox(height: 18),

              // Rotate button with animation.
              Center(
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _rotationController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 36,
                    ),
                    onPressed: _rotateClockwise,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Dependent rows.
              _buildRow(1, editable: false),
              const SizedBox(height: 12),
              _buildRow(2, editable: false),
              const SizedBox(height: 12),
              _buildRow(3, editable: false),
              const SizedBox(height: 120),
            ],
          ),
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
              onPressed: _isSyncing ? null : _onSynchronizePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _useMockRates ? Colors.grey[400] : Colors.yellow[700],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
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
                        fontSize: 18, fontWeight: FontWeight.bold),
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
