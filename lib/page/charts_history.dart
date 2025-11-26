// -----------------------------------------------------------------------------
// currentcy – Charts & History Screen
//
// This file contains:
// - The [ChartsHistory] widget (stateful)
// - Logic for loading and displaying historical exchange rates
// - Currency picker with favourites and search
// - A custom-painted line chart for the last 5 days
//
// Responsibilities:
// - Load settings (mock mode, premium plan, favourites)
// - Fetch historical rate data (live or mock)
// - Let users pick base and quote currencies
// - Render a lightweight custom chart for the selected pair
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:currentcy/services/currency_repository.dart';
import 'package:currentcy/settings/settings_manager.dart';

/// Charts & history screen.
///
/// Shows the last 5 days of exchange rate changes between a base and quote
/// currency, using either mock or live historical data depending on settings.
class ChartsHistory extends StatefulWidget {
  const ChartsHistory({super.key});

  @override
  State<ChartsHistory> createState() => _ChartsHistoryState();
}

class _ChartsHistoryState extends State<ChartsHistory> {
  /// Base currency code for the chart (left side).
  String _base = 'CHF';

  /// Quote currency code for the chart (right side).
  String _quote = 'EUR';

  /// True while initial setup or history loading is in progress.
  bool _isLoading = true;

  /// True while a live synchronization is in progress.
  bool _isSyncing = false;

  /// Whether mock rates are being used instead of live data.
  bool _useMockRates = true;

  /// Whether the user has a Professional/Business plan for live history.
  bool _hasPremiumPlan = false;

  /// Historical points for the currently selected currency pair.
  List<HistoryPoint> _points = [];

  /// All available currency codes for selection.
  List<String> _currencyOptions = [];

  /// Favourite currency codes used to highlight options in the picker.
  List<String> _favoriteCurrencies = [];

  /// Error message shown when loading history fails.
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  /// Initializes page state based on settings and available currencies.
  ///
  /// - Loads `useMockRates` and `hasPremiumPlan` from settings.
  /// - Loads all available currencies from [CurrencyRepository].
  /// - Normalizes base/quote currencies and favourites.
  /// - Starts history loading when allowed by settings.
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

    // Load favourites and keep only valid codes.
    final favs = await SettingsManager.loadFavoriteCurrencies();
    final validFavs =
        favs.where((c) => _currencyOptions.contains(c)).toList();

    // Ensure base and quote currencies are valid.
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

    // Do not load live history if live mode is on but no premium plan is available.
    if (!_useMockRates && !_hasPremiumPlan) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    await _loadHistory();
  }

  /// Loads historical rates for the current [_base]/[_quote] pair.
  ///
  /// Uses [CurrencyRepository.fetchHistoricalRates] to fetch the last 5 days.
  /// Sets [_points], [_isLoading] and [_error] accordingly.
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

  /// Handles tap on the "synchronize now" button.
  ///
  /// - Returns early if live mode is disabled or no premium plan is active.
  /// - In live mode, syncs rates and reloads history.
  Future<void> _onSyncPressed() async {
    // Only relevant when live mode is active and user has premium.
    if (!_useMockRates && !_hasPremiumPlan) return;

    // In mock mode there is nothing to sync.
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

  /// Opens a modal bottom sheet to pick a currency.
  ///
  /// - Displays favourites at the top, followed by all other currencies.
  /// - Provides a search field for code and name.
  /// - Returns the selected code, or `null` if the sheet was dismissed.
  Future<String?> _pickCurrency(String current) async {
    if (_currencyOptions.isEmpty) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final searchController = TextEditingController();

        // Base lists for favourites and other currencies.
        List<String> favBase = _favoriteCurrencies
            .where((c) => _currencyOptions.contains(c))
            .toList();
        List<String> othersBase = _currencyOptions
            .where((c) => !favBase.contains(c))
            .toList();

        // Filtered lists updated by search.
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

        // Initial state: no filter.
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
                              top: 8, bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Search field.
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

                        // Favourites + Divider + Others
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

  /// Returns the latest rate from [_points], if available.
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

            // Currency selectors (base & quote).
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

            // Main chart area / info / error states.
            Expanded(
              child: _buildChartArea(),
            ),
          ],
        ),
      ),

      // Footer with Sync button and info text.
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

  /// Builds the main chart area, including info & error states.
  ///
  /// Handles these cases:
  /// - Live mode without premium: info message instead of chart.
  /// - Loading: progress indicator.
  /// - Error: error text with retry button.
  /// - No points: guidance text.
  /// - Normal case: custom history chart.
  Widget _buildChartArea() {
    if (!_useMockRates && !_hasPremiumPlan) {
      // Live mode without premium → show info instead of chart.
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

  /// Builds a currency display box for [code].
  ///
  /// Shows flag, code and full name. When [reversed] is true, the flag
  /// is on the right and text on the left (used for base currency).
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

/// Hosts the custom-painted history chart for the provided [points].
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

/// Custom painter for the historical line chart.
///
/// Draws:
/// - Axes
/// - Line connecting all historical points
/// - Dots for each day
/// - Min/max labels on Y-axis
/// - Date labels (dd.MM) on X-axis
class _HistoryChartPainter extends CustomPainter {
  final List<HistoryPoint> points;

  _HistoryChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Axis style.
    final paintAxis = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;

    // Line style for the history curve.
    final paintLine = Paint()
      ..color = const Color(0xFF3F51B5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dot style for each data point.
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

    // Determine min/max rate for Y scaling.
    double minRate = points.first.rate;
    double maxRate = points.first.rate;
    for (final p in points) {
      if (p.rate < minRate) minRate = p.rate;
      if (p.rate > maxRate) maxRate = p.rate;
    }

    // Avoid division by ~0 when rates are effectively flat.
    if ((maxRate - minRate).abs() < 1e-6) {
      maxRate += 0.001;
      minRate -= 0.001;
    }

    final double yRange = maxRate - minRate;
    final double xStep =
        points.length > 1 ? chartWidth / (points.length - 1) : chartWidth;

    // Maps a [HistoryPoint] to a chart [Offset].
    Offset pointFor(int index, HistoryPoint p) {
      final x = paddingLeft + index * xStep;
      final norm = (p.rate - minRate) / yRange; // 0..1
      final y = paddingTop + (1 - norm) * chartHeight;
      return Offset(x, y);
    }

    // Axes.
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

    // Line connecting all points.
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

    // Dots on each point.
    for (int i = 0; i < points.length; i++) {
      final pt = pointFor(i, points[i]);
      canvas.drawCircle(pt, 3, paintDot);
    }

    // Helper for axis labels.
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

    // Y-axis min/max labels.
    drawYLabel(
      minRate,
      Offset(paddingLeft, size.height - paddingBottom),
    );
    drawYLabel(
      maxRate,
      Offset(paddingLeft, paddingTop),
    );

    // X-axis date labels (dd.MM).
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
