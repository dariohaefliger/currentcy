import 'package:flutter/material.dart';

class MultiConv extends StatefulWidget {
  const MultiConv({super.key});

  @override
  State<MultiConv> createState() => _MultiConvState();
}

class _MultiConvState extends State<MultiConv> with SingleTickerProviderStateMixin {
  // Controller: index 0 = main (editierbar), 1..3 = readOnly (grau)
  late List<TextEditingController> controllers;

  // Währungs-Liste (positionell): index 0 = Hauptwährung
  late List<String> currencies;

  // Mock-Wechselkurse (Basis: CHF = 1.0). Später durch API ersetzen.
  final Map<String, double> mockRates = {
    'CHF': 1.0,
    'EUR': 1.07,
    'USD': 0.94,
    'GBP': 1.21,
    'JPY': 0.0074,
    'AUD': 0.62,
    'CAD': 0.68,
  };

  // Animation für Rotation
  late AnimationController _rotationController;

  // verfügbare Auswahloptionen
  final List<String> currencyOptions = ['CHF','EUR','USD','GBP','JPY','AUD','CAD'];

  @override
  void initState() {
    super.initState();

    // initiale Währungen und Werte
    currencies = ['CHF', 'EUR', 'USD', 'GBP'];
    controllers = List.generate(4, (index) => TextEditingController());

    // Setze Startbetrag für Hauptfeld
    controllers[0].text = '100.00';

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // initiale Berechnung
    _recalculateFromMain();

    // Listener: wenn Hauptfeld sich ändert, neu berechnen
    controllers[0].addListener(_recalculateFromMain);
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    _rotationController.dispose();
    super.dispose();
  }

  // Hilfsfunktion: Rate von a -> b (to / from)
  double _rate(String from, String to) {
    final fromRate = mockRates[from] ?? 1.0;
    final toRate = mockRates[to] ?? 1.0;
    return toRate / fromRate;
  }

  // Rekalkuliere die drei unteren Felder basierend auf controllers[0] (Hauptbetrag)
  void _recalculateFromMain() {
    final txt = controllers[0].text.replaceAll(',', '.');
    final value = double.tryParse(txt);
    if (value == null) {
      // leere die unteren Felder
      for (int i = 1; i < controllers.length; i++) {
        controllers[i].text = '';
      }
      return;
    }

    final baseCurrency = currencies[0];
    for (int i = 1; i < currencies.length; i++) {
      final r = _rate(baseCurrency, currencies[i]);
      controllers[i].text = (value * r).toStringAsFixed(2);
    }
    // Falls du eine Anzeige des exakten Wechselkurses brauchst, kannst du sie hier berechnen.
    setState(() {}); // Werte aktualisieren
  }

  // Wird aufgerufen, wenn ein Dropdown an Position `index` geändert wird
  void _onCurrencyChanged(int index, String? newCode) {
    if (newCode == null) return;
    setState(() {
      currencies[index] = newCode;
    });
    // Wenn Hauptwährung geändert -> neu berechnen
    // Wenn eines der unteren Dropdowns geändert -> ebenfalls neu berechnen (Haupt bleibt Basis)
    _recalculateFromMain();
  }

  // Rotation im Uhrzeigersinn: rotiert sowohl currencies als auch Beträge
  void _rotateClockwise() async {
    // einfache visuelle Rotation
    await _rotationController.forward(from: 0.0);

    setState(() {
      // rotiere currencies: letzte wird zur ersten
      final lastCurrency = currencies.removeLast();
      currencies.insert(0, lastCurrency);

      // rotiere texte (Beträge): letzte wird zur ersten
      final lastText = controllers.last.text;
      for (int i = controllers.length - 1; i > 0; i--) {
        controllers[i].text = controllers[i - 1].text;
      }
      controllers[0].text = lastText;
    });

    // Nach Rotation: wir möchten, dass die unteren Werte sich an der (neuen) Hauptwährung orientieren.
    // Daher führen wir jetzt eine Neuberechnung durch basierend auf controllers[0] als Hauptbetrag.
    _recalculateFromMain();
  }

  // Snackbar für Synchronize
  void _onSynchronizePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronize: Rates updated (mock).'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Flaggen-Emoji für Anzeige (einfach)
  String _flagFor(String code) {
    switch (code) {
      case 'CHF': return '🇨🇭';
      case 'EUR': return '🇪🇺';
      case 'USD': return '🇺🇸';
      case 'GBP': return '🇬🇧';
      case 'JPY': return '🇯🇵';
      case 'AUD': return '🇦🇺';
      case 'CAD': return '🇨🇦';
      default: return '🏳️';
    }
  }

  // Widget: weißes editierbares Feld (Haupt)
  Widget _buildMainField() {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
        ),
        child: TextField(
          controller: controllers[0],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }

  // Widget: graues, readOnly Feld (für untere drei)
  Widget _buildDisabledField(int idx) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade300, // grau für nicht-editierbar
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
        ),
        child: TextField(
          controller: controllers[idx],
          readOnly: true,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }

  // Widget: Currency Dropdown (rechts vom Betrag). index = position in currencies/controllers
  Widget _buildCurrencyDropdown(int index) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currencies[index],
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            items: currencyOptions.map((code) {
              return DropdownMenuItem(
                value: code,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_flagFor(code), style: const TextStyle(fontSize: 20)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => _onCurrencyChanged(index, val),
          ),
        ),
      ),
    );
  }

  // Hilfs-Widget: Zeile mit Betrag + Dropdown (index gibt Position an)
  Widget _buildRow(int index, {required bool editable}) {
    return Row(
      children: [
        editable ? _buildMainField() : _buildDisabledField(index),
        const SizedBox(width: 12),
        _buildCurrencyDropdown(index),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body scrollt, Footer ist fixiert (bottomNavigationBar)
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
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
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 22),

              // Hauptfeld (index 0)
              _buildRow(0, editable: true),
              const SizedBox(height: 18),

              // Rotationsbutton (zentriert) mit Animation
              RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, size: 36, color: Colors.black54),
                  onPressed: _rotateClockwise,
                ),
              ),
              const SizedBox(height: 18),

              // Drei untere Ergebniszeilen (indices 1..3) - grau und readOnly
              _buildRow(1, editable: false),
              const SizedBox(height: 12),
              _buildRow(2, editable: false),
              const SizedBox(height: 12),
              _buildRow(3, editable: false),
              const SizedBox(height: 120), // Abstand über Footer
            ],
          ),
        ),
      ),

      // Fixierter Synchronize-Footer (gleiches Layout wie SingleConv)
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
