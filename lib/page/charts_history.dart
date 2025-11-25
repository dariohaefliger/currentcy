import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

class ChartsHistory extends StatefulWidget {
  const ChartsHistory({super.key});

  @override
  State<ChartsHistory> createState() => _ChartsHistoryState();
}

class _ChartsHistoryState extends State<ChartsHistory> {
  String _base = 'CHF';
  String _quote = 'EUR';

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _useMockRates = true;
  bool _hasPremiumPlan = false;

  List<HistoryPoint> _points = [];
  List<String> _currencyOptions = [];

  List<String> _favoriteCurrencies = [];

  String? _error;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final useMock = await SettingsManager.loadUseMockRates();
    final hasPremium = await SettingsManager.loadHasPremiumPlan();

    _useMockRates = useMock;
    _hasPremiumPlan = hasPremium;

    _currencyOptions = CurrencyRepository.getCurrencyCodes(_useMockRates);

    if (_currencyOptions.isEmpty) {
      setState(() {
        _error = 'No currencies available.';
        _isLoading = false;
      });
      return;
    }

    // load favourites
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final validFavs =
        favs.where((c) => _currencyOptions.contains(c)).toList();

    if (!_currencyOptions.contains(_base)) {
      _base = _currencyOptions.first;
    }
    if (!_currencyOptions.contains(_quote)) {
      _quote = _currencyOptions.length > 1
          ? _currencyOptions[1]
          : _currencyOptions.first;
    }

    setState(() {
      _favoriteCurrencies = validFavs;
    });

    // doesn't load if mock or not premium plan
    if (!_useMockRates && !_hasPremiumPlan) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final points = await CurrencyRepository.fetchHistoricalRates(
        base: _base,
        quote: _quote,
        days: 5,
      );

      setState(() {
        _points = points;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSyncPressed() async {
    if (!_useMockRates && !_hasPremiumPlan) return;

    if (_useMockRates) {
      return;
    }

    setState(() => _isSyncing = true);

    try {
      await CurrencyRepository.syncLiveRates();
      await _loadHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // --------------------------
  // SEARCHABLE PICKER
  // --------------------------

  Future<String?> _pickCurrency(String current) async {
    if (_currencyOptions.isEmpty) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();

        // Base-Listen
        List<String> favBase = _favoriteCurrencies
            .where((c) => _currencyOptions.contains(c))
            .toList();
        List<String> othersBase = _currencyOptions
            .where((c) => !favBase.contains(c))
            .toList();

        // Gefilterte Listen
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

        // initial without filter
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

                        // search
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

                        // Favs + Divider + Others
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
  }

  double? get _latestRate =>
      _points.isNotEmpty ? _points.last.rate : null;

  // --------------------------
  // BUILD
  // --------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            const Text(
              'Charts & History',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            const Text(
              'View the last 5 days of exchange rate changes between two currencies.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // Currency selectors
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final newVal = await _pickCurrency(_base);
                      if (newVal != null && newVal != _base) {
                        setState(() => _base = newVal);
                        if (_useMockRates || _hasPremiumPlan) {
                          _loadHistory();
                        }
                      }
                    },
                    child: _buildCurrencyBox(_base, reversed: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final newVal = await _pickCurrency(_quote);
                      if (newVal != null && newVal != _quote) {
                        setState(() => _quote = newVal);
                        if (_useMockRates || _hasPremiumPlan) {
                          _loadHistory();
                        }
                      }
                    },
                    child: _buildCurrencyBox(_quote, reversed: false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_latestRate != null)
              Text(
                '1 $_base = ${_latestRate!.toStringAsFixed(6)} $_quote (latest)',
                style: const TextStyle(fontSize: 13),
              ),

            const SizedBox(height: 16),

            Expanded(
              child: _buildChartArea(),
            ),
          ],
        ),
      ),

      // Footer with Sync button
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: (!_useMockRates && _hasPremiumPlan && !_isSyncing)
                  ? _onSyncPressed
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (!_useMockRates && _hasPremiumPlan)
                    ? Colors.yellow[700]
                    : Colors.grey[400],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _useMockRates
                        ? 'mock mode active'
                        : (!_hasPremiumPlan
                            ? 'requires Pro/Business'
                            : (_isSyncing
                                ? 'synchronizing...'
                                : 'synchronize now')),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_useMockRates)
              const Text(
                'Mock mode: charts use synthetic historical data and work on any plan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              )
            else if (!_hasPremiumPlan)
              const Text(
                'Live historical charts are only available for exchangeratesapi.io '
                'Professional and Business subscribers.\n'
                'If you have such a plan, enable it in Settings > ExchangeRates API.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea() {
    if (!_useMockRates && !_hasPremiumPlan) {
      // Live + kein Premium → Info statt Chart
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Live historical charts are only available for '
            'exchangeratesapi.io Professional and Business plans.\n\n'
            'You can still use mock mode, or enable the "Professional / Business plan" '
            'toggle in Settings if you have the required subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_error\n\nThis feature won\'t work, if you do not have a pro/business plan!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_points.isEmpty) {
      return const Center(
        child: Text(
          'No history available yet.\nTap "synchronize now" (if available) or enable mock mode.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return Center(
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: _HistoryChart(points: _points),
      ),
    );
  }

  // CURRENCY PICKER
  Widget _buildCurrencyBox(String code, {required bool reversed}) {
    final flag = CurrencyRepository.flagFor(code);
    final name = CurrencyRepository.nameFor(code);

    final flagWidget = Text(
      flag,
      style: const TextStyle(fontSize: 26, color: Colors.black),
    );

    final textWidget = Expanded(
      child: Column(
        crossAxisAlignment:
            reversed ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black),
      ),
      child: Row(
        children: reversed
            ? [
                textWidget,
                const SizedBox(width: 10),
                flagWidget,
              ]
            : [
                flagWidget,
                const SizedBox(width: 10),
                textWidget,
              ],
      ),
    );
  }
}

// -----------------------------
// CHART WIDGET
// -----------------------------

class _HistoryChart extends StatelessWidget {
  final List<HistoryPoint> points;

  const _HistoryChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HistoryChartPainter(points: points),
      child: Container(),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<HistoryPoint> points;

  _HistoryChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintAxis = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = const Color(0xFF3F51B5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = const Color(0xFF3F51B5)
      ..style = PaintingStyle.fill;

    const double paddingLeft = 40;
    const double paddingRight = 20;
    const double paddingTop = 16;
    const double paddingBottom = 28;

    final chartWidth =
        size.width - paddingLeft - paddingRight;
    final chartHeight =
        size.height - paddingTop - paddingBottom;

    double minRate = points.first.rate;
    double maxRate = points.first.rate;
    for (final p in points) {
      if (p.rate < minRate) minRate = p.rate;
      if (p.rate > maxRate) maxRate = p.rate;
    }

    if ((maxRate - minRate).abs() < 1e-6) {
      maxRate += 0.001;
      minRate -= 0.001;
    }

    final double yRange = maxRate - minRate;
    final double xStep =
        points.length > 1 ? chartWidth / (points.length - 1) : chartWidth;

    Offset pointFor(int index, HistoryPoint p) {
      final x = paddingLeft + index * xStep;
      final norm = (p.rate - minRate) / yRange; // 0..1
      final y = paddingTop + (1 - norm) * chartHeight;
      return Offset(x, y);
    }

    // Achsen
    final axisBottom = Offset(
      paddingLeft,
      size.height - paddingBottom,
    );
    final axisBottomEnd = Offset(
      size.width - paddingRight,
      size.height - paddingBottom,
    );
    final axisLeft = Offset(paddingLeft, paddingTop);
    final axisLeftEnd = Offset(
      paddingLeft,
      size.height - paddingBottom,
    );

    canvas.drawLine(axisBottom, axisBottomEnd, paintAxis);
    canvas.drawLine(axisLeft, axisLeftEnd, paintAxis);

    // Linie
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = pointFor(i, points[i]);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, paintLine);

    // Punkte
    for (int i = 0; i < points.length; i++) {
      final pt = pointFor(i, points[i]);
      canvas.drawCircle(pt, 3, paintDot);
    }

    // Text-Helper
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );

    void drawYLabel(double value, Offset pos) {
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(4),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
        ),
      );
      textPainter.layout(minWidth: 0, maxWidth: paddingLeft - 4);
      final offset = Offset(
        paddingLeft - textPainter.width - 4,
        pos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    // y-Achse min/max
    drawYLabel(
      minRate,
      Offset(paddingLeft, size.height - paddingBottom),
    );
    drawYLabel(
      maxRate,
      Offset(paddingLeft, paddingTop),
    );

    // x-Achse Datum (dd.MM)
    for (int i = 0; i < points.length; i++) {
      final pt = pointFor(i, points[i]);
      final d = points[i].date.toLocal();
      final label =
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
        ),
      );
      textPainter.layout(minWidth: 0, maxWidth: 40);
      final offset = Offset(
        pt.dx - textPainter.width / 2,
        size.height - paddingBottom + 4,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
