import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/smooth_wheel.dart';

TextStyle _t(Color color, double size, FontWeight weight, {double? letterSpacing}) =>
    GoogleFonts.urbanist(
        color: color, fontSize: size, fontWeight: weight, letterSpacing: letterSpacing);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime? _selectedMonth;

  String _formatMonth(DateTime month) => DateFormat.yMMM().format(month);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final expenseMonths = provider.expenseMonths;
    _selectedMonth ??= expenseMonths.isNotEmpty ? expenseMonths.last : DateTime.now();
  }

  /// Category slice colors: only the four brand colors, cycling with lighter tints.
  Color _sliceColor(BuildContext context, int i) {
    final base = context.isDark
        ? [AppTheme.lime, AppTheme.blue, AppTheme.lavender, AppTheme.white]
        : [AppTheme.blue, AppTheme.lime, AppTheme.ink, AppTheme.lavender];
    final tier = (i ~/ base.length) % 3;
    final alpha = tier == 0 ? 1.0 : (tier == 1 ? 0.65 : 0.4);
    return base[i % base.length].withValues(alpha: alpha);
  }

  Color _onColor(Color c) => Color.alphaBlend(c, AppTheme.white).computeLuminance() > 0.5
      ? AppTheme.ink
      : AppTheme.white;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final transactions = provider.transactions;

    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    final netSavings = totalIncome - totalExpense;

    final availableMonths = provider.expenseMonths;
    final selectedMonth = _selectedMonth ??
        (availableMonths.isNotEmpty ? availableMonths.last : DateTime.now());
    final selectedMonthSpending = provider.spendingByCategoryForMonth(selectedMonth);
    final totalCategorySpend = selectedMonthSpending.values.fold<double>(0, (a, b) => a + b);
    final selectedMonthTotal = provider.totalExpenseForMonth(selectedMonth);
    final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final previousMonthTotal = provider.totalExpenseForMonth(previousMonth);
    final monthDifference = selectedMonthTotal - previousMonthTotal;
    final monthDifferencePct =
        previousMonthTotal > 0 ? (monthDifference / previousMonthTotal * 100).abs() : 0.0;
    final weeklySpending = provider.weeklySpendingForMonth(selectedMonth);
    final runningTotals = provider.runningExpenseForMonth(selectedMonth);
    final budgetWarnings = provider.budgetVarianceForMonth(selectedMonth);
    final monthlySpending = _getMonthlySpending(transactions);

    final sectionTitle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      body: SafeArea(
        child: transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                            color: AppTheme.lime, shape: BoxShape.circle),
                        child: const Icon(Icons.pie_chart_rounded,
                            size: 40, color: AppTheme.ink),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add some transactions to see your analytics',
                        textAlign: TextAlign.center,
                        style: _t(context.fg, 17, FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: SmoothWheel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview\nstatistics',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),

                    // --- Net hero ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: netSavings >= 0 ? AppTheme.blue : context.cta,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  netSavings >= 0 ? 'Net savings' : 'Net deficit',
                                  style: _t(
                                      (netSavings >= 0 ? AppTheme.white : context.onCta)
                                          .withValues(alpha: 0.85),
                                      14,
                                      FontWeight.w600),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: netSavings >= 0 ? AppTheme.lime : AppTheme.blue,
                                    shape: BoxShape.circle),
                                child: Icon(
                                  netSavings >= 0
                                      ? Icons.north_east_rounded
                                      : Icons.south_east_rounded,
                                  color: netSavings >= 0 ? AppTheme.ink : AppTheme.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${netSavings >= 0 ? '+' : ''}${formatCurrency.format(netSavings)}',
                              style: _t(netSavings >= 0 ? AppTheme.white : context.onCta,
                                  42, FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryTile(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Income',
                            amount: formatCurrency.format(totalIncome),
                            bg: AppTheme.lime,
                            fg: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryTile(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Expense',
                            amount: formatCurrency.format(totalExpense),
                            bg: context.soft,
                            fg: context.onSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // --- Spending by Category ---
                    Text('Spending by category', style: sectionTitle),
                    const SizedBox(height: 12),
                    _buildMonthSelector(context, selectedMonth, availableMonths),
                    const SizedBox(height: 16),

                    if (selectedMonthSpending.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Text(
                                'No expenses recorded for ${_formatMonth(selectedMonth)}',
                                style: _t(context.fg, 15, FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Select a different month or add expenses to see your category breakdown.',
                                style: _t(context.fgMuted, 13, FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total ${_formatMonth(selectedMonth)}',
                                      style: _t(context.fgMuted, 14, FontWeight.w600)),
                                  Text(formatCurrency.format(selectedMonthTotal),
                                      style: _t(context.fg, 16, FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _buildPieSections(
                                        context, selectedMonthSpending, totalCategorySpend),
                                    centerSpaceRadius: 44,
                                    sectionsSpace: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...selectedMonthSpending.entries
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final category = entry.value.key;
                                final amount = entry.value.value;
                                final pct = totalCategorySpend > 0
                                    ? (amount / totalCategorySpend * 100).round()
                                    : 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _sliceColor(context, entry.key),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(category,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _t(context.fg, 14, FontWeight.w600)),
                                      ),
                                      Text(formatCurrency.format(amount),
                                          style: _t(context.fg, 14, FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 40,
                                        child: Text('$pct%',
                                            textAlign: TextAlign.right,
                                            style: _t(context.fgMuted, 13, FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),

                    // --- Month comparison ---
                    Text('Month comparison', style: sectionTitle),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _compareRow(context, 'Selected month',
                                _formatMonth(selectedMonth), formatCurrency.format(selectedMonthTotal)),
                            const SizedBox(height: 16),
                            _compareRow(context, 'Previous month',
                                _formatMonth(previousMonth), formatCurrency.format(previousMonthTotal)),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: monthDifference >= 0 ? context.cta : AppTheme.lime,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    monthDifference >= 0 ? 'Spend increased' : 'Spend decreased',
                                    style: _t(monthDifference >= 0 ? context.onCta : AppTheme.ink,
                                        12, FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${monthDifference >= 0 ? '+' : '-'}${formatCurrency.format(monthDifference.abs())} (${monthDifferencePct.toStringAsFixed(1)}%)',
                                      style: _t(context.fg, 13, FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Weekly spending ---
                    Text('Weekly spending', style: sectionTitle),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < weeklySpending.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            weeklySpending[index]['label'] as String,
                                            style: _t(context.fgFaint, 11, FontWeight.w600),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              barGroups: weeklySpending.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value['amount'] as double,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                      color: context.accent,
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Running total ---
                    Text('Running total', style: sectionTitle),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (v) =>
                                    FlLine(color: context.border, strokeWidth: 1),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    interval: runningTotals.isNotEmpty &&
                                            (runningTotals.last['amount'] as double) > 0
                                        ? (runningTotals.last['amount'] as double) / 4
                                        : 1,
                                    getTitlesWidget: (value, meta) => Text(
                                      meta.formattedValue,
                                      style: _t(context.fgFaint, 10, FontWeight.w600),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < runningTotals.length) {
                                        final day = runningTotals[index]['day'] as int;
                                        if (day % 5 == 1 || day == runningTotals.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(day.toString(),
                                                style: _t(context.fgFaint, 11, FontWeight.w600)),
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: runningTotals.asMap().entries.map((entry) {
                                    return FlSpot(entry.key.toDouble(), entry.value['amount'] as double);
                                  }).toList(),
                                  isCurved: true,
                                  color: context.accent,
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: context.accent.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Budget warnings ---
                    Text('Budget warnings', style: sectionTitle),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: budgetWarnings.isEmpty
                            ? Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                        color: AppTheme.lime, shape: BoxShape.circle),
                                    child: const Icon(Icons.check_rounded,
                                        size: 18, color: AppTheme.ink),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'All tracked budgets are within limit for ${_formatMonth(selectedMonth)}.',
                                      style: _t(context.fgMuted, 14, FontWeight.w600),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: budgetWarnings.entries.map((entry) {
                                  final budget = provider.categoryBudgets[entry.key] ?? 0;
                                  final spend =
                                      provider.spendingByCategoryForMonth(selectedMonth)[entry.key] ?? 0;
                                  final over = entry.value;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(entry.key,
                                                style: _t(context.fg, 15, FontWeight.w700)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: context.cta,
                                                borderRadius:
                                                    BorderRadius.circular(AppTheme.radiusPill),
                                              ),
                                              child: Text(
                                                '+${formatCurrency.format(over)} over',
                                                style: _t(context.onCta, 11, FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                          child: LinearProgressIndicator(
                                            value: budget > 0 ? (spend / budget).clamp(0.0, 1.0) : 0,
                                            minHeight: 10,
                                            color: AppTheme.blue,
                                            backgroundColor: context.isDark
                                                ? AppTheme.white.withValues(alpha: 0.12)
                                                : AppTheme.lavender,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${formatCurrency.format(spend)} / ${formatCurrency.format(budget)}',
                                          style: _t(context.fgMuted, 12, FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Monthly spending trend ---
                    Text('Monthly spending trend', style: sectionTitle),
                    const SizedBox(height: 12),

                    if (monthlySpending.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('Not enough data for trend yet',
                                style: _t(context.fgMuted, 14, FontWeight.w600)),
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LAST 6 MONTHS',
                                  style: _t(context.fgMuted, 12, FontWeight.w700,
                                      letterSpacing: 1)),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBgColor:
                                            context.isDark ? AppTheme.lavender : AppTheme.ink,
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            formatCurrency.format(rod.toY),
                                            _t(context.isDark ? AppTheme.ink : AppTheme.white,
                                                12, FontWeight.w700),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 && index < monthlySpending.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Text(
                                                  monthlySpending[index]['label'] as String,
                                                  style: _t(context.fgFaint, 11, FontWeight.w600),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: monthlySpending.asMap().entries.map((entry) {
                                      final isLatest = entry.key == monthlySpending.length - 1;
                                      return BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: entry.value['amount'] as double,
                                            color: isLatest
                                                ? context.accent
                                                : (context.isDark
                                                    ? AppTheme.lavender.withValues(alpha: 0.35)
                                                    : AppTheme.lavender),
                                            width: 22,
                                            borderRadius:
                                                BorderRadius.circular(AppTheme.radiusPill),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                )),
              ),
      ),
    );
  }

  Widget _compareRow(BuildContext context, String caption, String month, String amount) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: _t(context.fgMuted, 12, FontWeight.w600)),
              const SizedBox(height: 4),
              Text(month, style: _t(context.fg, 15, FontWeight.w700)),
            ],
          ),
        ),
        Text(amount, style: _t(context.fg, 17, FontWeight.w700)),
      ],
    );
  }

  Widget _buildMonthSelector(
      BuildContext context, DateTime selectedMonth, List<DateTime> availableMonths) {
    if (availableMonths.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: context.soft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: selectedMonth,
          isExpanded: true,
          dropdownColor: context.bg,
          borderRadius: BorderRadius.circular(20),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.onSoft),
          style: _t(context.onSoft, 15, FontWeight.w700),
          items: availableMonths.map((monthValue) {
            return DropdownMenuItem<DateTime>(
              value: monthValue,
              child: Text(_formatMonth(monthValue),
                  style: _t(context.fg, 15, FontWeight.w700)),
            );
          }).toList(),
          onChanged: (monthValue) {
            if (monthValue != null) {
              setState(() {
                _selectedMonth = monthValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String amount,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount, style: _t(fg, 21, FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label, style: _t(fg.withValues(alpha: 0.65), 12, FontWeight.w600)),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      BuildContext context, Map<String, double> categorySpending, double total) {
    final entries = categorySpending.entries.toList();
    return entries.asMap().entries.map((entry) {
      final color = _sliceColor(context, entry.key);
      final amount = entry.value.value;
      final pct = total > 0 ? (amount / total * 100) : 0.0;

      return PieChartSectionData(
        value: amount,
        color: color,
        radius: 56,
        title: '${pct.round()}%',
        titleStyle: _t(_onColor(color), 11, FontWeight.w700),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getMonthlySpending(List transactions) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthLabel = DateFormat.MMM().format(monthDate);
      double total = 0;

      for (var t in transactions) {
        if (!t.isIncome && t.date.year == monthDate.year && t.date.month == monthDate.month) {
          total += t.amount;
        }
      }

      result.add({'label': monthLabel, 'amount': total});
    }

    final hasData = result.any((m) => (m['amount'] as double) > 0);
    return hasData ? result : [];
  }
}
