import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  // User-adjustable overrides; null means "use computed value"
  double? _incomeOverride;
  double? _expenseOverride;
  double _extraSavings = 0; // additional monthly savings

  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final currencySymbol = provider.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Compute real averages from transaction history ──
    final avgIncome = _computeAverageMonthlyIncome(provider);
    final avgExpense = _computeAverageMonthlyExpense(provider);

    // Initialize sliders from real data on first build
    if (!_initialized && (avgIncome > 0 || avgExpense > 0)) {
      _incomeOverride = avgIncome;
      _expenseOverride = avgExpense;
      _initialized = true;
    }

    final effectiveIncome = _incomeOverride ?? avgIncome;
    final effectiveExpense = _expenseOverride ?? avgExpense;
    final monthlyNet = effectiveIncome - effectiveExpense + _extraSavings;

    final currentBalance = provider.currentBalance;
    final projectedBalance12 = currentBalance + (monthlyNet * 12);

    // ── Build chart data ──
    List<FlSpot> forecastSpots = [];
    List<FlSpot> goalSpots = [];
    final hasGoal = provider.monthlyGoal > 0;

    for (int i = 0; i <= 12; i++) {
      forecastSpots
          .add(FlSpot(i.toDouble(), currentBalance + (monthlyNet * i)));
      if (hasGoal) {
        goalSpots.add(
            FlSpot(i.toDouble(), currentBalance + (provider.monthlyGoal * i)));
      }
    }

    // Calculate Y-axis bounds for proper scaling
    final allValues = forecastSpots.map((s) => s.y).toList();
    if (hasGoal) allValues.addAll(goalSpots.map((s) => s.y));
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs();
    final chartMinY = minY - (yRange * 0.1);
    final chartMaxY = maxY + (yRange * 0.1);

    // ── Summary stats ──
    final isPositiveNetFlow = monthlyNet >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Cards Row ──
              Row(
                children: [
                  _SummaryChip(
                    icon: Icons.trending_up_rounded,
                    label: 'Monthly Net',
                    value:
                        '${monthlyNet >= 0 ? '+' : ''}${formatCurrency.format(monthlyNet)}',
                    color: isPositiveNetFlow
                        ? AppTheme.brandDefault
                        : Colors.redAccent,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _SummaryChip(
                    icon: Icons.calendar_today_rounded,
                    label: '12-Month',
                    value: formatCurrency.format(projectedBalance12),
                    color: projectedBalance12 >= 0
                        ? AppTheme.brandDefault
                        : Colors.redAccent,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Projection Chart ──
              Text('Projected Balance',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legend
                      Row(
                        children: [
                          const _LegendDot(
                              color: AppTheme.brandDefault, label: 'Forecast'),
                          if (hasGoal) ...[
                            const SizedBox(width: 16),
                            _LegendDot(
                                color: Colors.amber.shade700,
                                label: 'Goal Target'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: LineChart(
                          LineChartData(
                            minY: chartMinY,
                            maxY: chartMaxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval:
                                  yRange > 0 ? yRange / 4 : 1000,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.06),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 52,
                                  interval: yRange > 0 ? yRange / 4 : 1000,
                                  getTitlesWidget: (value, meta) {
                                    if (value == meta.min ||
                                        value == meta.max) {
                                      return const SizedBox.shrink();
                                    }
                                    String label;
                                    if (value.abs() >= 100000) {
                                      label =
                                          '$currencySymbol${(value / 100000).toStringAsFixed(1)}L';
                                    } else if (value.abs() >= 1000) {
                                      label =
                                          '$currencySymbol${(value / 1000).toStringAsFixed(0)}K';
                                    } else {
                                      label = '$currencySymbol${value.toStringAsFixed(0)}';
                                    }
                                    return Text(label,
                                        style: const TextStyle(
                                            fontSize: 9, color: Colors.grey));
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: 3,
                                  getTitlesWidget: (value, meta) {
                                    final month = value.toInt();
                                    if (month == 0 ||
                                        month == 3 ||
                                        month == 6 ||
                                        month == 9 ||
                                        month == 12) {
                                      final futureDate = DateTime.now().add(
                                          Duration(days: month * 30));
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Text(
                                          month == 0
                                              ? 'Now'
                                              : DateFormat.MMM()
                                                  .format(futureDate),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final isGoalLine =
                                        spot.barIndex == 1;
                                    return LineTooltipItem(
                                      '${formatCurrency.format(spot.y)}\n${isGoalLine ? 'Goal' : 'Forecast'} — Mo ${spot.x.toInt()}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              // Forecast line
                              LineChartBarData(
                                spots: forecastSpots,
                                isCurved: true,
                                color: AppTheme.brandDefault,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.brandDefault
                                          .withValues(alpha: 0.2),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // Goal line (dashed)
                              if (hasGoal)
                                LineChartBarData(
                                  spots: goalSpots,
                                  isCurved: true,
                                  color: Colors.amber.shade700,
                                  barWidth: 2,
                                  isStrokeCapRound: true,
                                  dashArray: [6, 4],
                                  dotData: const FlDotData(show: false),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Income/Expense Breakdown ──
              Text('Monthly Breakdown',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Based on your transaction history',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 12),
              _BreakdownCard(
                icon: Icons.arrow_downward_rounded,
                iconColor: AppTheme.brandDefault,
                label: 'Avg Monthly Income',
                computed: avgIncome,
                current: effectiveIncome,
                formatCurrency: formatCurrency,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _BreakdownCard(
                icon: Icons.arrow_upward_rounded,
                iconColor: Colors.redAccent,
                label: 'Avg Monthly Expenses',
                computed: avgExpense,
                current: effectiveExpense,
                formatCurrency: formatCurrency,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // ── Simulation Sliders ──
              Text('Adjust Forecast',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Drag sliders to simulate "what if" scenarios',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _ForecastSlider(
                        label: 'Monthly Income',
                        subtext: 'Salary, freelance, deposits',
                        value: effectiveIncome,
                        min: 0,
                        max: (avgIncome * 3).clamp(10000, 500000),
                        color: AppTheme.brandDefault,
                        onChanged: (val) =>
                            setState(() => _incomeOverride = val),
                        formatCurrency: formatCurrency,
                      ),
                      Divider(
                          height: 28,
                          color: isDark ? Colors.white12 : Colors.black12),
                      _ForecastSlider(
                        label: 'Monthly Expenses',
                        subtext: 'Rent, bills, groceries, etc.',
                        value: effectiveExpense,
                        min: 0,
                        max: (avgExpense * 3).clamp(10000, 500000),
                        color: Colors.redAccent,
                        onChanged: (val) =>
                            setState(() => _expenseOverride = val),
                        formatCurrency: formatCurrency,
                      ),
                      Divider(
                          height: 28,
                          color: isDark ? Colors.white12 : Colors.black12),
                      _ForecastSlider(
                        label: 'Extra Savings',
                        subtext: 'Additional monthly investment',
                        value: _extraSavings,
                        min: 0,
                        max: (avgIncome * 0.5).clamp(5000, 100000),
                        color: Colors.amber.shade700,
                        onChanged: (val) =>
                            setState(() => _extraSavings = val),
                        formatCurrency: formatCurrency,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reset button
              if (_initialized)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _incomeOverride = avgIncome;
                        _expenseOverride = avgExpense;
                        _extraSavings = 0;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset to Actuals'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compute real averages ──

  double _computeAverageMonthlyIncome(FinanceProvider provider) {
    if (provider.transactions.isEmpty) return 0;
    double total = 0;
    Set<String> months = {};
    for (var t in provider.transactions) {
      if (t.isIncome) {
        total += t.amount;
        months.add('${t.date.year}-${t.date.month}');
      }
    }
    // Use all months that have any transaction data for averaging
    final allMonths = <String>{};
    for (var t in provider.transactions) {
      allMonths.add('${t.date.year}-${t.date.month}');
    }
    return allMonths.isNotEmpty ? total / allMonths.length : 0;
  }

  double _computeAverageMonthlyExpense(FinanceProvider provider) {
    if (provider.transactions.isEmpty) return 0;
    double total = 0;
    final allMonths = <String>{};
    for (var t in provider.transactions) {
      if (!t.isIncome) {
        total += t.amount;
      }
      allMonths.add('${t.date.year}-${t.date.month}');
    }
    return allMonths.isNotEmpty ? total / allMonths.length : 0;
  }
}

// ── Reusable Widgets ──

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double computed;
  final double current;
  final NumberFormat formatCurrency;
  final bool isDark;

  const _BreakdownCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.computed,
    required this.current,
    required this.formatCurrency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isAdjusted = (current - computed).abs() > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (isAdjusted)
                  Text(
                    'Computed: ${formatCurrency.format(computed)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Text(
            formatCurrency.format(current),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastSlider extends StatelessWidget {
  final String label;
  final String subtext;
  final double value;
  final double min;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;
  final NumberFormat formatCurrency;

  const _ForecastSlider({
    required this.label,
    required this.subtext,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtext,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            Text(
              formatCurrency.format(value),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 50,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
