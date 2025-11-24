import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

class MultiConv extends StatefulWidget {
  const MultiConv({super.key});

  @override
  State<MultiConv> createState() => _MultiConvState();
}

class _MultiConvState extends State<MultiConv>
    with SingleTickerProviderStateMixin {
  // Controllers: index 0 = main (editable), 1..3 = readOnly (grey)
  late List<TextEditingController> controllers;

  // Currency list (positional): index 0 = base currency
  late List<String> currencies;

  // Current rates (mock or live, depending on _useMockRates)
  Map<String, double> _rates = {};

  // Available currency codes (sorted)
  List<String> _currencyOptions = [];

  // Animation controller for rotation
  late AnimationController _rotationController;

  bool _useMockRates = true;
  bool _isSyncing = false;
  bool _isLoading = true;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();

    // initial 4 currencies
    currencies = ['CHF', 'EUR', 'USD', 'GBP'];

    controllers = List.generate(4, (index) => TextEditingController());
    controllers[0].text = '100.00';

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    controllers[0].addListener(_recalculateFromMain);

    _initSettingsAndRates();
  }

  Future<void> _initSettingsAndRates() async {
    final useMock = await SettingsManager.loadUseMockRates();
    await CurrencyRepository.loadLastSync();

    final rates = CurrencyRepository.getRates(useMock);
    final options = CurrencyRepository.getCurrencyCodes(useMock);

    // Ensure each currency in the initial list is valid
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

  double _rate(String from, String to) {
    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;
    return toRate / fromRate;
  }

  // Recalculate rows 1..3 based on controllers[0]
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

  void _onCurrencyChanged(int index, String newCode) {
    setState(() {
      currencies[index] = newCode;
    });
    _recalculateFromMain();
  }

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

      // Make sure each currency is still valid
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

  // ---- currency picker with search (code + full name) ----

  Future<void> _showCurrencyPicker(int index) async {
    if (_currencyOptions.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final searchController = TextEditingController();
        List<String> filtered = List.of(_currencyOptions);

        void applyFilter(String query) {
          final q = query.toLowerCase();
          filtered = _currencyOptions.where((code) {
            final name = CurrencyRepository.nameFor(code);
            return code.toLowerCase().contains(q) ||
                name.toLowerCase().contains(q);
          }).toList();
        }

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search currency (code or name)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            applyFilter(value);
                          });
                        },
                      ),
                    ),
                    // List of currencies
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final code = filtered[i];
                          final flag = CurrencyRepository.flagFor(code);
                          final name = CurrencyRepository.nameFor(code);
                          return ListTile(
                            leading: Text(
                              flag,
                              style: const TextStyle(fontSize: 28, color: Colors.black),
                            ),
                            title: Text(name),
                            subtitle: Text(code),
                            onTap: () => Navigator.of(context).pop(code),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      _onCurrencyChanged(index, selected);
    }
  }

  String _flagFor(String code) => CurrencyRepository.flagFor(code);
  String _nameFor(String code) => CurrencyRepository.nameFor(code);

  String _formatLastSyncText() {
    if (_useMockRates) {
      return 'Mock mode is enabled. Go to Settings to disable it and fetch live exchange rates.';
    }
    if (_lastSync == null) {
      return 'Last synchronization: never\nYou may synchronize now to get the most recent exchange rates.';
    }
    final d = _lastSync!;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return 'Last synchronization: $dateStr\nYou may synchronize now to get the most recent exchange rates.';
  }

  // ---- UI building helpers ----

  Widget _buildMainField() {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, 
          color: Colors.black
          ),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }

  Widget _buildDisabledField(int idx) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  // The currency "chip" on the right side (with popup on tap)
  Widget _buildCurrencyChip(int index) {
    final code = currencies[index];
    final flag = _flagFor(code);
    final name = _nameFor(code);

    return Expanded(
      flex: 1,
      child: GestureDetector(
        onTap: () => _showCurrencyPicker(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black12),
          ),
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
                          fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ],
                ),
              ),
              Text(
                flag,
                style: const TextStyle(fontSize: 20, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            children: [
              const SizedBox(height: 8),
              const Text(
                'Multi Conversion',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edit the top amount. Pick currencies for each row. Use the rotate button to rotate currencies & amounts clockwise.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, 
                //color: Colors.black54
                ),
              ),
              const SizedBox(height: 22),

              // Main row (index 0)
              _buildRow(0, editable: true),
              const SizedBox(height: 18),

              // Rotation button
              RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _rotationController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 36, 
                      //color: Colors.black54
                      ),
                  onPressed: _rotateClockwise,
                ),
              ),
              const SizedBox(height: 18),

              // Result rows (1..3)
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

      // Footer with sync button & info
      bottomNavigationBar: Container(
        //color: Colors.white,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              _formatLastSyncText(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, 
                  //color: Colors.black54
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
