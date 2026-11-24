import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../models/financial_goal.dart';
import '../services/forecast_service.dart';
import '../widgets/ai_forecast_insight_card.dart';
import '../widgets/add_goal_sheet.dart';
import '../widgets/add_budget_sheet.dart';
import '../widgets/save_to_goal_sheet.dart';
import '../widgets/tap_scale.dart';
import '../widgets/smooth_wheel.dart';

Color _track(BuildContext context) => context.isDark
    ? AppTheme.white.withValues(alpha: 0.12)
    : AppTheme.lavender;

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
    final stats = provider.monthlyStats;
    // Monthly money available for goals: realistic income minus spending.
    final monthlyNet = stats.income - stats.expense;
    final annualReturn = provider.expectedReturn;
    final split = ForecastService.splitAcrossGoals(
        provider.goals, monthlyNet > 0 ? monthlyNet : 0);
    final formatCurrency = provider.currencyFormat;

    final budgets = provider.categoryBudgets;
    final monthSpending = provider.currentMonthSpendingByCategory;
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: SmoothWheel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text('Budgets &\nGoals',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 24),

              // ── Monthly Overview ──
              _MonthlyOverviewCard(
                month: monthName,
                totalSpent: provider.totalCurrentMonthSpending,
                totalIncome: provider.currentMonthIncome,
                formatCurrency: formatCurrency,
              ),
              const SizedBox(height: 32),

              // ── Category Budgets ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly Budgets',
                      style: Theme.of(context).textTheme.titleLarge),
                  TapScale(
                    onTap: () => _showAddBudget(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.lime,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 16, color: AppTheme.ink),
                          const SizedBox(width: 4),
                          Text('Add',
                              style: GoogleFonts.urbanist(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (budgets.isEmpty)
                const _EmptyStateCard(
                  icon: Icons.pie_chart_outline,
                  title: 'No budgets set',
                  subtitle: 'Tap "+ Add" to create a category budget',
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: context.border),
                  ),
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
                            barColor = context.isDark
                                ? AppTheme.blue
                                : AppTheme.ink;
                          } else if (progress > 0.8) {
                            barColor = AppTheme.blue;
                          } else {
                            barColor = context.isDark
                                ? AppTheme.lime
                                : AppTheme.blue;
                          }

                          return Column(
                            children: [
                              if (i > 0) const SizedBox(height: 22),
                              Dismissible(
                                key: Key('budget_$category'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Icon(Icons.delete_outline,
                                      color: context.fg, size: 22),
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
                                              child: const Text('Delete'),
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
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Unbudgeted spending
              if (budgets.isNotEmpty) ...[
                const SizedBox(height: 12),
                _UnbudgetedSpending(
                  budgets: budgets,
                  monthSpending: monthSpending,
                  formatCurrency: formatCurrency,
                ),
              ],

              const SizedBox(height: 32),

              // ── Savings Goals ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Savings Goals',
                      style: Theme.of(context).textTheme.titleLarge),
                  TapScale(
                    onTap: () => _showAddGoal(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: context.cta, shape: BoxShape.circle),
                      child: Icon(Icons.add_rounded,
                          color: context.onCta, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (provider.goals.isEmpty)
                _EmptyStateCard(
                  icon: Icons.flag_outlined,
                  title: 'No savings goals yet',
                  subtitle: 'Set a goal to start tracking your progress',
                  action: ElevatedButton.icon(
                    onPressed: () => _showAddGoal(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Goal'),
                  ),
                )
              else
                ...provider.goals.asMap().entries.map((e) {
                  final index = e.key;
                  final goal = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Dismissible(
                      key: Key(goal.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: context.cta,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusCard),
                        ),
                        child: Icon(Icons.delete_outline,
                            color: context.onCta, size: 28),
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
                                      child: const Text('Delete')),
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
                        index: index,
                        monthlyNet: split[goal.id] ?? 0,
                        annualReturn: annualReturn,
                        formatCurrency: formatCurrency,
                      ),
                    ),
                  );
                }),
              if (provider.goals.isNotEmpty) ...[
                const SizedBox(height: 8),
                AiForecastInsightCard(
                  title: 'AI coach: reach goals sooner',
                  buildFacts: () {
                    final b = StringBuffer()
                      ..writeln(
                          'Monthly income ${stats.income.toStringAsFixed(0)}, spending ${stats.expense.toStringAsFixed(0)}, free for goals ${monthlyNet.toStringAsFixed(0)}.')
                      ..writeln(
                          'Assumed yearly return ${(annualReturn * 100).toStringAsFixed(1)}%.');
                    for (final g in provider.goals) {
                      final m = ForecastService.monthsToGoal(
                          g, split[g.id] ?? 0,
                          annualReturn: annualReturn);
                      final need = ForecastService.requiredMonthly(g, 12,
                          annualReturn: annualReturn);
                      b.writeln(
                          'Goal ${g.title}: ${g.savedAmount.toStringAsFixed(0)}/${g.targetAmount.toStringAsFixed(0)}, gets ${(split[g.id] ?? 0).toStringAsFixed(0)}/month, ${m == null ? 'not reachable at this rate' : m == 0 ? 'reached' : 'reached in ${ForecastService.formatMonths(m)}'}; needs ${need.toStringAsFixed(0)}/month to finish within 12 months.');
                    }
                    return b.toString();
                  },
                ),
              ],

              const SizedBox(height: 100),
            ],
          )),
        ),
      ),
    );
  }

  Widget _goalCard(BuildContext context,
      {required FinancialGoal goal,
      required int index,
      required double monthlyNet,
      required double annualReturn,
      required NumberFormat formatCurrency}) {
    final percent = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount * 100).clamp(0, 100).toInt()
        : 0;
    final isCompleted = goal.savedAmount >= goal.targetAmount;

    final months = ForecastService.monthsToGoal(goal, monthlyNet,
        annualReturn: annualReturn);
    String timeText = months == null || months == 0
        ? 'Needs more savings'
        : '${ForecastService.formatMonths(months)} left';
    final needed12 =
        ForecastService.requiredMonthly(goal, 12, annualReturn: annualReturn);
    if (isCompleted) timeText = 'Goal reached!';

    // Alternate blue / lavender blocks; completed goals turn lime.
    final bool onBlue = !isCompleted && index.isEven;
    final Color cardBg = isCompleted
        ? AppTheme.lime
        : (onBlue ? AppTheme.blue : context.soft);
    final Color textColor = onBlue ? AppTheme.white : (isCompleted ? AppTheme.ink : context.onSoft);
    final Color subColor = textColor.withValues(alpha: 0.7);
    final Color trackColor = onBlue
        ? AppTheme.white.withValues(alpha: 0.25)
        : AppTheme.white.withValues(alpha: isCompleted ? 0.5 : (context.isDark ? 0.12 : 0.6));
    final Color fillColor = onBlue
        ? AppTheme.lime
        : (isCompleted ? AppTheme.ink : AppTheme.blue);
    final Color chipBg = onBlue ? AppTheme.lime : (isCompleted ? AppTheme.ink : AppTheme.lime);
    final Color chipFg = onBlue ? AppTheme.ink : (isCompleted ? AppTheme.lime : AppTheme.ink);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.title,
                    style: GoogleFonts.urbanist(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
                child: Icon(
                  isCompleted ? Icons.check_rounded : Icons.north_east_rounded,
                  color: chipFg,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent%',
                  style: GoogleFonts.urbanist(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: textColor)),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '${formatCurrency.format(goal.savedAmount)} / ${formatCurrency.format(goal.targetAmount)}',
                        style: GoogleFonts.urbanist(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 10),
            Text(
                'Save ${formatCurrency.format(needed12)}/month to finish in 1 year'
                '${annualReturn > 0 ? ' (at ${(annualReturn * 100).toStringAsFixed(0)}% return)' : ''}',
                style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subColor)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted ? Icons.emoji_events : Icons.schedule,
                      size: 14,
                      color: chipFg,
                    ),
                    const SizedBox(width: 6),
                    Text(timeText,
                        style: GoogleFonts.urbanist(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: chipFg)),
                  ],
                ),
              ),
              const Spacer(),
              if (!isCompleted)
                TapScale(
                  onTap: () => _showSaveToGoal(context, goal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: onBlue ? AppTheme.white : AppTheme.ink,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.savings_outlined,
                            size: 16,
                            color: onBlue ? AppTheme.ink : AppTheme.white),
                        const SizedBox(width: 6),
                        Text('Save',
                            style: GoogleFonts.urbanist(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: onBlue ? AppTheme.ink : AppTheme.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Monthly Overview Card ──

class _MonthlyOverviewCard extends StatelessWidget {
  final String month;
  final double totalSpent;
  final double totalIncome;
  final NumberFormat formatCurrency;

  const _MonthlyOverviewCard({
    required this.month,
    required this.totalSpent,
    required this.totalIncome,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final netSavings = totalIncome - totalSpent;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.blue,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$month overview',
                  style: GoogleFonts.urbanist(
                    color: AppTheme.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency.format(netSavings),
              style: GoogleFonts.urbanist(
                color: AppTheme.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          Text(
            'Net this month',
            style: GoogleFonts.urbanist(
                color: AppTheme.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Income',
                  value: formatCurrency.format(totalIncome),
                  bg: AppTheme.lavender,
                  fg: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Spent',
                  value: formatCurrency.format(totalSpent),
                  bg: AppTheme.ink,
                  fg: AppTheme.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Saved',
                  value: '${savingsRate.toStringAsFixed(0)}%',
                  bg: AppTheme.lime,
                  fg: AppTheme.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  const _StatTile({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile - 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700, fontSize: 17, color: fg),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: 0.65)),
          ),
        ],
      ),
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

  const _BudgetRow({
    required this.category,
    required this.spent,
    required this.limit,
    required this.barColor,
    required this.isOver,
    required this.formatCurrency,
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
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (isOver) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.cta,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      'OVER',
                      style: GoogleFonts.urbanist(
                        color: context.onCta,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
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
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.fg,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${formatCurrency.format(limit)}',
                    style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: _track(context),
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

  const _UnbudgetedSpending({
    required this.budgets,
    required this.monthSpending,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
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
          'Other spending this month',
          style: GoogleFonts.urbanist(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.fgMuted,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: unbudgeted.entries.map((e) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: context.soft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.onSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency.format(e.value),
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.isDark ? AppTheme.lime : AppTheme.blue,
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
  final Widget? action;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.soft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppTheme.lime, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: AppTheme.ink),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: context.onSoft)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                  color: context.onSoft.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
