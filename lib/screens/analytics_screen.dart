import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

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

  // Generate distinct colors for pie chart slices
  static const List<Color> _sliceColors = [
    AppTheme.brandDefault,
    Color(0xFF00BFFF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFFE040FB),
    Color(0xFF00E676),
    Color(0xFFFF9100),
    Color(0xFF448AFF),
    Color(0xFFB388FF),
    Color(0xFF80DEEA),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = provider.transactions;

    // Calculate totals
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

    // Spending per category
    final availableMonths = provider.expenseMonths;
    final selectedMonth = _selectedMonth ??
        (availableMonths.isNotEmpty ? availableMonths.last : DateTime.now());
    final selectedMonthSpending = provider.spendingByCategoryForMonth(selectedMonth);
    final totalCategorySpend = selectedMonthSpending.values.fold<double>(0, (a, b) => a + b);
    final selectedMonthTotal = provider.totalExpenseForMonth(selectedMonth);
    final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final previousMonthTotal = provider.totalExpenseForMonth(previousMonth);
    final monthDifference = selectedMonthTotal - previousMonthTotal;
    final monthDifferencePct = previousMonthTotal > 0 ? (monthDifference / previousMonthTotal * 100).abs() : 0.0;
    final weeklySpending = provider.weeklySpendingForMonth(selectedMonth);
    final runningTotals = provider.runningExpenseForMonth(selectedMonth);
    final budgetWarnings = provider.budgetVarianceForMonth(selectedMonth);

    // Monthly spending for bar chart (last 6 months)
    final monthlySpending = _getMonthlySpending(transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart, size: 80, color: isDark ? Colors.white24 : Colors.black12),
                  const SizedBox(height: 16),
                  const Text(
                    'Add some transactions to see your analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Section B: Income vs Expense ---
                    Text('Overview', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            context,
                            icon: Icons.arrow_downward,
                            label: 'Income',
                            amount: formatCurrency.format(totalIncome),
                            color: AppTheme.brandDefault,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            context,
                            icon: Icons.arrow_upward,
                            label: 'Expense',
                            amount: formatCurrency.format(totalExpense),
                            color: Colors.redAccent,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: netSavings >= 0
                            ? AppTheme.brandDefault.withValues(alpha: 0.08)
                            : Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: netSavings >= 0
                              ? AppTheme.brandDefault.withValues(alpha: 0.2)
                              : Colors.redAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            netSavings >= 0 ? 'Net Savings' : 'Net Deficit',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: netSavings >= 0 ? AppTheme.brandDark : Colors.redAccent,
                            ),
                          ),
                          Text(
                            '${netSavings >= 0 ? '+' : ''}${formatCurrency.format(netSavings)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: netSavings >= 0 ? AppTheme.brandDark : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Section A: Spending by Category (Pie Chart) ---
                    Text('Spending by Category', style: Theme.of(context).textTheme.titleMedium),
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
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a different month or add expenses to see your category breakdown.',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
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
                                  Text(
                                    'Total ${_formatMonth(selectedMonth)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    formatCurrency.format(selectedMonthTotal),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _buildPieSections(selectedMonthSpending, totalCategorySpend),
                                    centerSpaceRadius: 40,
                                    sectionsSpace: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Legend
                              ...selectedMonthSpending.entries.toList().asMap().entries.map((entry) {
                                final colorIndex = entry.key % _sliceColors.length;
                                final category = entry.value.key;
                                final amount = entry.value.value;
                                final pct = totalCategorySpend > 0
                                    ? (amount / totalCategorySpend * 100).toInt()
                                    : 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _sliceColors[colorIndex],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          category,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Text(
                                        formatCurrency.format(amount),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 40,
                                        child: Text(
                                          '$pct%',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('Month Comparison', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Selected Month', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatMonth(selectedMonth),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatCurrency.format(selectedMonthTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Previous Month', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatMonth(previousMonth),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatCurrency.format(previousMonthTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthDifference >= 0 ? 'Spend increased' : 'Spend decreased',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: monthDifference >= 0 ? Colors.redAccent : AppTheme.brandDefault,
                                  ),
                                ),
                                Text(
                                  '${monthDifference >= 0 ? '+' : '-'}${formatCurrency.format(monthDifference.abs())} (${monthDifferencePct.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: monthDifference >= 0 ? Colors.redAccent : AppTheme.brandDefault,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Weekly Spending', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 180,
                              child: BarChart(
                                BarChartData(
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
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
                                            return Text(
                                              weeklySpending[index]['label'] as String,
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                                          width: 18,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(6),
                                          ),
                                          color: AppTheme.brandDefault,
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
                    const SizedBox(height: 24),
                    Text('Running Total', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: runningTotals.isNotEmpty ? (runningTotals.last['amount'] as double) / 4 : 1),
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
                                          return Text(
                                            day.toString(),
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                                  color: AppTheme.brandDefault,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppTheme.brandDefault.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Budget Warnings', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: budgetWarnings.isEmpty
                            ? Text(
                                'All tracked budgets are within limit for ${_formatMonth(selectedMonth)}.',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              )
                            : Column(
                                children: budgetWarnings.entries.map((entry) {
                                  final budget = provider.categoryBudgets[entry.key] ?? 0;
                                  final spend = provider.spendingByCategoryForMonth(selectedMonth)[entry.key] ?? 0;
                                  final over = entry.value;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            Text(
                                              '+${formatCurrency.format(over)} over budget',
                                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: (spend / budget).clamp(0.0, 1.0),
                                          color: Colors.redAccent,
                                          backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${formatCurrency.format(spend)} / ${formatCurrency.format(budget)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Section C: Monthly Spending Trend (Bar Chart) ---
                    Text('Monthly Spending Trend', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),

                    if (monthlySpending.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Not enough data for trend yet',
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                            ),
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
                              const Text(
                                'Last 6 Months',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBgColor: Colors.black87,
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            formatCurrency.format(rod.toY),
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: monthlySpending.asMap().entries.map((entry) {
                                      return BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: entry.value['amount'] as double,
                                            gradient: const LinearGradient(
                                              colors: [AppTheme.brandDefault, AppTheme.brandDark],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            width: 20,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(6),
                                              topRight: Radius.circular(6),
                                            ),
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
                ),
              ),
            ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, DateTime selectedMonth, List<DateTime> availableMonths) {
    if (availableMonths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select month',
          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: selectedMonth,
              isExpanded: true,
              items: availableMonths.map((monthValue) {
                return DropdownMenuItem<DateTime>(
                  value: monthValue,
                  child: Text(_formatMonth(monthValue)),
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
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> categorySpending, double total) {
    final entries = categorySpending.entries.toList();
    return entries.asMap().entries.map((entry) {
      final colorIndex = entry.key % _sliceColors.length;
      final amount = entry.value.value;
      final pct = total > 0 ? (amount / total * 100) : 0.0;

      return PieChartSectionData(
        value: amount,
        color: _sliceColors[colorIndex],
        radius: 55,
        title: '${pct.toInt()}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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

    // Only return if there's at least some data
    final hasData = result.any((m) => (m['amount'] as double) > 0);
    return hasData ? result : [];
  }
}
