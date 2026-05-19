import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/transfer_sheet.dart';
import 'transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _showAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  void _showTransfer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransferSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build Initials
    String initials = "AR";
    if (provider.userName.isNotEmpty) {
      final parts = provider.userName.split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = provider.userName.substring(0, provider.userName.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    // Mini Chart Data
    List<FlSpot> spots = [];
    final reversedList = provider.transactions.reversed.toList();
    for (int i = 0; i < reversedList.length && i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), reversedList[i].amount));
    }
    if (spots.isEmpty) spots = [const FlSpot(0, 0)];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GOOD MORNING', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(provider.userName, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        color: isDark ? AppTheme.brandDark : Colors.grey,
                        onPressed: () {
                           provider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                        },
                      ),
                      CircleAvatar(
                        backgroundColor: AppTheme.brandDefault,
                        foregroundColor: Colors.black,
                        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Total Balance Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Balance', style: Theme.of(context).textTheme.bodyMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.brandDefault.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16)
                            ),
                            child: const Text('+2.4%', style: TextStyle(color: AppTheme.brandDefault, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(formatCurrency.format(provider.currentBalance), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('7-DAY TREND', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const Text('Avg Spend', style: TextStyle(color: AppTheme.brandDefault, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: AppTheme.brandDefault,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [AppTheme.brandDefault.withValues(alpha: 0.3), Colors.transparent],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showAddTransaction(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Ink(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.brandDefault,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(60)),
                                child: const Icon(Icons.add, color: Colors.black)
                            ),
                            const SizedBox(height: 12),
                            const Text('Add Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showTransfer(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Ink(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
                        ),
                        child: Column(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.brandDefault.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(60)),
                                child: const Icon(Icons.swap_horiz, color: AppTheme.brandDefault)
                            ),
                            const SizedBox(height: 12),
                            Text('Transfer', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Forecast Snapshot
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.brandDefault.withValues(alpha: 0.05),
                  border: Border.all(color: AppTheme.brandDefault.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(24)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                         Icon(Icons.bolt, color: AppTheme.brandDefault, size: 20),
                         SizedBox(width: 8),
                         Text('FORECAST SNAPSHOT', style: TextStyle(color: AppTheme.brandDefault, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text('Projected Balance (30 Days)', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text(formatCurrency.format(provider.currentBalance + provider.averageMonthlyNet), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ]
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                                Text('Est. Savings', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text('+${formatCurrency.format(provider.averageMonthlyNet > 0 ? provider.averageMonthlyNet : 0)}', style: const TextStyle(color: AppTheme.brandDefault, fontWeight: FontWeight.bold, fontSize: 16)),
                            ]
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 0.75, // Static example per the design
                        backgroundColor: isDark ? Colors.black26 : Colors.black12,
                        minHeight: 6,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.brandDefault),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(child: Text('Based on average recurring income and fixed expenses.', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)))
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionScreen())),
                    child: const Text('View All →', style: TextStyle(color: AppTheme.brandDefault, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (provider.transactions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('No transactions yet. Tap "Add Details" to get started!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                ...provider.transactions.take(5).map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: t.isIncome
                              ? AppTheme.brandDefault.withValues(alpha: 0.12)
                              : Colors.redAccent.withValues(alpha: 0.12),
                          child: Icon(
                            t.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: t.isIncome ? AppTheme.brandDark : Colors.redAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(DateFormat.yMMMd().format(t.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          '${t.isIncome ? '+' : '-'}${formatCurrency.format(t.amount)}',
                          style: TextStyle(
                            color: t.isIncome ? AppTheme.brandDark : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
