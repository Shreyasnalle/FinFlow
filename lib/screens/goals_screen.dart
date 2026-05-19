import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../models/financial_goal.dart';
import '../widgets/add_goal_sheet.dart';
import '../widgets/add_budget_sheet.dart';
import '../widgets/save_to_goal_sheet.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  void _showAddGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGoalSheet(),
    );
  }

  void _showAddBudget(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddBudgetSheet(),
    );
  }

  void _showSaveToGoal(BuildContext context, FinancialGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveToGoalSheet(goal: goal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final monthlyNet = provider.averageMonthlyNet;
    final formatCurrency = provider.currencyFormat;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final budgets = provider.categoryBudgets; // { category: limit }
    final monthSpending =
        provider.currentMonthSpendingByCategory; // { category: spent }
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Goals',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: AppTheme.brandDefault, size: 28),
            onPressed: () => _showAddGoal(context),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Monthly Overview ──
              _MonthlyOverviewCard(
                month: monthName,
                totalSpent: provider.totalCurrentMonthSpending,
                totalIncome: provider.currentMonthIncome,
                formatCurrency: formatCurrency,
                isDark: isDark,
              ),
              const SizedBox(height: 28),

              // ── Category Budgets ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly Budgets',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => _showAddBudget(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.brandDefault,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (budgets.isEmpty)
                _EmptyStateCard(
                  icon: Icons.pie_chart_outline,
                  title: 'No budgets set',
                  subtitle: 'Tap "+ Add" to create a category budget',
                  isDark: isDark,
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ...budgets.entries.toList().asMap().entries.map(
                          (entry) {
                            final i = entry.key;
                            final category = entry.value.key;
                            final limit = entry.value.value;
                            final spent = monthSpending[category] ?? 0;
                            final progress =
                                limit > 0 ? (spent / limit).clamp(0.0, 1.5) : 0.0;
                            final isOver = spent > limit;

                            Color barColor;
                            if (isOver) {
                              barColor = Colors.redAccent;
                            } else if (progress > 0.8) {
                              barColor = Colors.orangeAccent;
                            } else {
                              barColor = AppTheme.brandDefault;
                            }

                            return Column(
                              children: [
                                if (i > 0) const SizedBox(height: 20),
                                Dismissible(
                                  key: Key('budget_$category'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent, size: 22),
                                  ),
                                  confirmDismiss: (_) async {
                                    return await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Remove Budget?'),
                                            content: Text(
                                                'Delete the "$category" budget?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.redAccent)),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                  },
                                  onDismissed: (_) {
                                    provider.removeCategoryBudget(category);
                                  },
                                  child: _BudgetRow(
                                    category: category,
                                    spent: spent,
                                    limit: limit,
                                    barColor: barColor,
                                    isOver: isOver,
                                    formatCurrency: formatCurrency,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Unbudgeted spending
              if (budgets.isNotEmpty) ...[
                const SizedBox(height: 12),
                _UnbudgetedSpending(
                  budgets: budgets,
                  monthSpending: monthSpending,
                  formatCurrency: formatCurrency,
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 32),

              // ── Savings Goals ──
              Text('Savings Goals',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),

              if (provider.goals.isEmpty)
                _EmptyStateCard(
                  icon: Icons.flag_outlined,
                  title: 'No savings goals yet',
                  subtitle: 'Set a goal to start tracking your progress',
                  isDark: isDark,
                  action: ElevatedButton.icon(
                    onPressed: () => _showAddGoal(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Goal'),
                  ),
                )
              else
                ...provider.goals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Dismissible(
                        key: Key(goal.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Goal?'),
                                  content: Text(
                                      'Are you sure you want to delete "${goal.title}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.redAccent))),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) {
                          provider.deleteGoal(goal.id);
                        },
                        child: _goalCard(
                          context,
                          goal: goal,
                          monthlyNet: monthlyNet,
                          formatCurrency: formatCurrency,
                          isDark: isDark,
                        ),
                      ),
                    )),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalCard(BuildContext context,
      {required FinancialGoal goal,
      required double monthlyNet,
      required NumberFormat formatCurrency,
      required bool isDark}) {
    final percent = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount * 100).clamp(0, 100).toInt()
        : 0;
    final isCompleted = goal.savedAmount >= goal.targetAmount;

    int monthsRemaining = 0;
    if (monthlyNet > 0 && goal.targetAmount > goal.savedAmount) {
      monthsRemaining =
          ((goal.targetAmount - goal.savedAmount) / monthlyNet).ceil();
    }
    String timeText =
        monthlyNet > 0 ? '$monthsRemaining months left' : 'Needs more savings';
    if (isCompleted) timeText = 'Goal reached!';

    return Card(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppTheme.brandDefault.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.track_changes,
                  color: isCompleted ? Colors.green : AppTheme.brandDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(goal.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        Text('$percent%',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${formatCurrency.format(goal.savedAmount)} / ${formatCurrency.format(goal.targetAmount)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 8,
                        backgroundColor:
                            isDark ? Colors.black26 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? Colors.green : AppTheme.brandDefault),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(
                        isCompleted ? Icons.emoji_events : Icons.schedule,
                        size: 14,
                        color:
                            isCompleted ? Colors.green : AppTheme.brandDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isCompleted ? Colors.green : AppTheme.brandDark,
                        ),
                      ),
                    ])
                  ],
                ),
              ),
            ],
          ),
          // Save button row
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSaveToGoal(context, goal),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('Save Money'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandDark,
                  side: const BorderSide(color: AppTheme.brandDefault),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}

// ── Monthly Overview Card ──

class _MonthlyOverviewCard extends StatelessWidget {
  final String month;
  final double totalSpent;
  final double totalIncome;
  final NumberFormat formatCurrency;
  final bool isDark;

  const _MonthlyOverviewCard({
    required this.month,
    required this.totalSpent,
    required this.totalIncome,
    required this.formatCurrency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final netSavings = totalIncome - totalSpent;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2a2a2a), const Color(0xFF1e1e1e)]
              : [AppTheme.brandDefault.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.brandDefault.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppTheme.brandDefault, size: 18),
              const SizedBox(width: 6),
              Text(
                '$month Overview',
                style: const TextStyle(
                  color: AppTheme.brandDefault,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Income',
                  value: formatCurrency.format(totalIncome),
                  color: AppTheme.brandDefault,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Spent',
                  value: formatCurrency.format(totalSpent),
                  color: Colors.redAccent,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Saved',
                  value: '${savingsRate.toStringAsFixed(0)}%',
                  color: netSavings >= 0 ? AppTheme.brandDefault : Colors.redAccent,
                  icon: Icons.savings_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

// ── Budget Row ──

class _BudgetRow extends StatelessWidget {
  final String category;
  final double spent;
  final double limit;
  final Color barColor;
  final bool isOver;
  final NumberFormat formatCurrency;
  final bool isDark;

  const _BudgetRow({
    required this.category,
    required this.spent,
    required this.limit,
    required this.barColor,
    required this.isOver,
    required this.formatCurrency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(category,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (isOver) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OVER',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatCurrency.format(spent),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isOver
                          ? Colors.redAccent
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${formatCurrency.format(limit)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: isDark ? Colors.black26 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ── Unbudgeted Spending ──

class _UnbudgetedSpending extends StatelessWidget {
  final Map<String, double> budgets;
  final Map<String, double> monthSpending;
  final NumberFormat formatCurrency;
  final bool isDark;

  const _UnbudgetedSpending({
    required this.budgets,
    required this.monthSpending,
    required this.formatCurrency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Find categories with spending but no budget set
    final unbudgeted = <String, double>{};
    for (final entry in monthSpending.entries) {
      if (!budgets.containsKey(entry.key)) {
        unbudgeted[entry.key] = entry.value;
      }
    }

    if (unbudgeted.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Other Spending This Month',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: unbudgeted.entries.map((e) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency.format(e.value),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Empty State Card ──

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget? action;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12)),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
