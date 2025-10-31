import 'package:flutter/material.dart';

class SingleConv extends StatefulWidget {
  const SingleConv({super.key});

  @override
  State<SingleConv> createState() => _SingleConvState();
}

class _SingleConvState extends State<SingleConv> {
  final TextEditingController fromController = TextEditingController(text: '12.50');
  final TextEditingController toController = TextEditingController(text: '13.38');

  // Beispielhafte Wechselkurse (Mock-Daten)
  Map<String, double> mockRates = {
    'CHF': 1.0,
    'EUR': 1.07,
    'USD': 0.94,
    'GBP': 1.21,
  };

  String fromCurrency = 'CHF';
  String toCurrency = 'EUR';

  @override
  void initState() {
    super.initState();
    fromController.addListener(_onFromAmountChanged);
  }

  @override
  void dispose() {
    fromController.removeListener(_onFromAmountChanged);
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  // Betragseingabe -> Zielwert berechnen
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
    final fromRate = mockRates[from] ?? 1.0;
    final toRate = mockRates[to] ?? 1.0;
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
  }

  // Snackbar beim Synchronisieren
  void _onSynchronizePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronize: Rates updated')),
    );
  }

  // Snackbar bei falscher Eingabe
  void _onRightButtonPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your input into the left box.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Währungsauswahl via BottomSheet
  Future<void> _showCurrencyPicker({required bool isFrom}) async {
    final currencies = ['CHF', 'EUR', 'USD', 'GBP', 'JPY', 'AUD', 'CAD'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Text('Select currency')),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currencies.length,
                  itemBuilder: (context, index) {
                    final code = currencies[index];
                    return ListTile(
                      leading: Text(_getFlag(code), style: const TextStyle(fontSize: 28)),
                      title: Text(_currencyFullName(code)),
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
    );

    if (selected != null) {
      setState(() {
        if (isFrom) {
          fromCurrency = selected;
        } else {
          toCurrency = selected;
        }
        _onFromAmountChanged();
      });
    }
  }

  // Flaggen-Icons
  String _getFlag(String code) {
    switch (code) {
      case 'CHF':
        return '🇨🇭';
      case 'EUR':
        return '🇪🇺';
      case 'USD':
        return '🇺🇸';
      case 'GBP':
        return '🇬🇧';
      case 'JPY':
        return '🇯🇵';
      case 'AUD':
        return '🇦🇺';
      case 'CAD':
        return '🇨🇦';
      default:
        return '🏳️';
    }
  }

  String _currencyFullName(String code) {
    switch (code) {
      case 'CHF':
        return 'Swiss Franc';
      case 'EUR':
        return 'Euro';
      case 'USD':
        return 'US Dollar';
      case 'GBP':
        return 'British Pound';
      case 'JPY':
        return 'Japanese Yen';
      case 'AUD':
        return 'Australian Dollar';
      case 'CAD':
        return 'Canadian Dollar';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stil für die Zahleneingabefelder
    final fieldDecorationLeft = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
      ],
    );

    final fieldDecorationRight = BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Convert currency',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap on the fields below to change the amount and currency.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // Zahlenfelder (Eingabe & Ausgabe)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: fieldDecorationLeft,
                    child: TextField(
                      controller: fromController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration.collapsed(hintText: ''),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, size: 36),
                        onPressed: _swapCurrencies,
                      ),
                      const Text('swap', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: fieldDecorationRight,
                    child: TextField(
                      controller: toController,
                      readOnly: true,
                      onTap: _onRightButtonPressed,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration.collapsed(hintText: ''),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Währungswahl (Flagge rechts)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCurrencyPicker(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fromCurrency,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_currencyFullName(fromCurrency),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(_getFlag(fromCurrency),
                              style: const TextStyle(fontSize: 26)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCurrencyPicker(isFrom: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(toCurrency,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_currencyFullName(toCurrency),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(_getFlag(toCurrency),
                              style: const TextStyle(fontSize: 26)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Wechselkursanzeige
            Center(
              child: Text(
                '1 $fromCurrency = ${_getRate(fromCurrency, toCurrency).toStringAsFixed(6)} $toCurrency',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 120), // Platz über fixiertem Footer
          ],
        ),
      ),

      // Fixierter Footer mit Synchronize-Button
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _onSynchronizePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('synchronize now',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(width: 10),
                  Icon(Icons.sync),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last synchronization: 26.10.2025 11:26\nYou may synchronize now to get the most recent exchange rates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
