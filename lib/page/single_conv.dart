import 'package:flutter/material.dart';

class SingleConv extends StatefulWidget {
  const SingleConv({super.key});

  @override
  State<SingleConv> createState() => _SingleConvState();
}

class _SingleConvState extends State<SingleConv> {
  final TextEditingController fromController = TextEditingController(text: '12.50');
  final TextEditingController toController = TextEditingController(text: '13.38');

  // Mock-Werte müssen durch API ersetzt werden.
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
    // Wenn der Benutzer den Betrag ändert, berechne Mock-Konvertierung
    fromController.addListener(_onFromAmountChanged);
  }

  @override
  void dispose() {
    fromController.removeListener(_onFromAmountChanged);
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  void _onFromAmountChanged() {
    // Nimmt sowohl Komma als auch Punkt entgegen.
    final text = fromController.text.replaceAll(',', '.');
    final value = double.tryParse(text);
    if (value == null) {
      setState(() => toController.text = '');
      return;
    }
    final rate = _getRate(fromCurrency, toCurrency);
    final converted = value * rate;
    // Formatieren auf 2 Nachkommastellen
    toController.text = converted.toStringAsFixed(2);
  }

  double _getRate(String from, String to) {
    final fromRate = mockRates[from] ?? 1.0;
    final toRate = mockRates[to] ?? 1.0;
    // Beispiel: rate von "from" zu "to"
    return toRate / fromRate;
  }

  void _swapCurrencies() {
    // Swap-Button: Tauscht beide Beträge und Währungen
    setState(() {
      final oldFrom = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = oldFrom;

      final oldFromText = fromController.text;
      fromController.text = toController.text;
      toController.text = oldFromText;
    });
  }

// Auswahlliste der Währungen:
  Future<void> _showCurrencyPicker({required bool isFrom}) async {
    // Beispiel-Liste: Muss erweitert werden durch Angebote aus API
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
                    color: Colors.grey.shade200,
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
                      leading: _buildFlagPlaceholder(code),
                      title: Text(_currencyFullName(code)),
                      subtitle: Text(code),
                      onTap: () {
                        Navigator.of(context).pop(code);
                      },
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
          // Recalculate after currency change:
          _onFromAmountChanged();
        } else {
          toCurrency = selected;
          _onFromAmountChanged();
        }
      });
    }
  }

  // Platzhalter für Flagge. Benutze Image.asset(...) und lade die entsprechenden SVG/PNG Assets der Flaggen in assets/flags/
  Widget _buildFlagPlaceholder(String code) {
    return Container(
      width: 40,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.pinkAccent,
      ),
      child: Text(
        code,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

// Vollständige Liste mit Währungsnamen für obere Auswahlliste.
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

// Funktionsweise des Synchronize-Buttons.
  void _onSynchronizePressed() {
    // Hier später den API-Aufruf einbauen.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronize: Rates updated')),
    );
  }

// Verweis auf linkes Eingabefeld, falls das rechte angeklickt wird.
    void _onRightButtonPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your input into the left box.'),
        backgroundColor: Colors.blue,
        ),
    );
  }

// Placement der Widgets
  @override
  Widget build(BuildContext context) {

    // Zahlenfelder

    // Links
    final fieldDecorationLinks = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    );

    // Rechts
        final fieldDecorationRechts = BoxDecoration(
      color: Colors.grey,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    );

    return SingleChildScrollView(
      // damit auf kleinen Bildschirmen alles scrollt, wenn Keyboard sichtbar ist.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          // Instructions-Text über den Feldern
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

            // Oberer Bereich: Zahlenwerte
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Linker Input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: fieldDecorationLinks,
                    child: TextField(
                      controller: fromController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration.collapsed(hintText: ''),
                    ),
                  ),
                ),

                // Swap-Button in der Mitte
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

                // Rechts kein Input möglich. Swap-Button wird vorausgesetzt.
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: fieldDecorationRechts,
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

            // Untere Reihe: Währungswahl für from / to
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCurrencyPicker(isFrom: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          _buildFlagPlaceholder(fromCurrency),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fromCurrency, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(_currencyFullName(fromCurrency), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          _buildFlagPlaceholder(toCurrency),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(toCurrency, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(_currencyFullName(toCurrency), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Synchronize-Button
            Center(
              child: ElevatedButton(
                onPressed: _onSynchronizePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('synchronize now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(width: 10),
                    Icon(Icons.sync),
                  ],
                ),
              ),
            ),

            // Beschreibung für Synchronize-Button (momentan noch hard-coded)
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Last synchronization: 26.10.2025 11:26\nYou may synchronize now to get the most recent exchange rates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),

            const SizedBox(height: 26),
            // Exakter Wechselkurs zuunterst.
            Center(
              child: Text(
                '1 $fromCurrency = ${_getRate(fromCurrency, toCurrency).toStringAsFixed(6)} $toCurrency',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
