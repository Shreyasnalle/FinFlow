import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/financial_goal.dart';
import '../providers/finance_provider.dart';
import '../services/forecast_service.dart';
import '../widgets/ai_forecast_insight_card.dart';
import '../theme/app_theme.dart';
import '../utils/app_calendar.dart';
import '../widgets/smooth_wheel.dart';

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


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final currencySymbol = provider.currencySymbol;

    // ── Realistic averages: last 6 full months, recency-weighted ──
    final stats = provider.monthlyStats;
    final avgIncome = stats.income;
    final avgExpense = stats.expense;
    final avgInvest = stats.investment;
    final annualReturn = provider.expectedReturn;

    final effectiveIncome = _incomeOverride ?? avgIncome;
    final effectiveExpense = _expenseOverride ?? avgExpense;
    // Cash left after spending and existing investing.
    final cashNet = effectiveIncome - effectiveExpense - avgInvest;
    // Total put aside each month (cash savings + SIP-style investing).
    final monthlyNet = effectiveIncome - effectiveExpense + _extraSavings;

    final currentBalance = provider.currentBalance;
    final points = ForecastService.projectBalance(
      currentBalance: currentBalance,
      monthlyNet: cashNet,
      netStdDev: stats.netStdDev,
      monthlyInvest: avgInvest + _extraSavings,
      annualReturn: annualReturn,
    );
    final projectedBalance12 = points.last.expected;
    final noGrowth12 = currentBalance + monthlyNet * 12;
    final growth12 = projectedBalance12 - noGrowth12;

    // ── Build chart data ──
    final forecastSpots = [
      for (final pt in points) FlSpot(pt.month.toDouble(), pt.expected)
    ];
    final lowSpots = [
      for (final pt in points) FlSpot(pt.month.toDouble(), pt.low)
    ];
    final highSpots = [
      for (final pt in points) FlSpot(pt.month.toDouble(), pt.high)
    ];
    List<FlSpot> goalSpots = [];
    final hasGoal = provider.monthlyGoal > 0;
    if (hasGoal) {
      for (int i = 0; i <= 12; i++) {
        goalSpots.add(
            FlSpot(i.toDouble(), currentBalance + (provider.monthlyGoal * i)));
      }
    }

    // Calculate Y-axis bounds for proper scaling
    final allValues = [...lowSpots, ...forecastSpots, ...highSpots].map((s) => s.y).toList();
    if (hasGoal) allValues.addAll(goalSpots.map((s) => s.y));
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs();
    final chartMinY = minY - (yRange * 0.1);
    final chartMaxY = maxY + (yRange * 0.1);

    // ── Summary stats ──
    final isPositiveNetFlow = monthlyNet >= 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: SmoothWheel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Track your\nforecast',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 24),

              // ── Hero projection card ──
              _HeroProjection(
                value: formatCurrency.format(projectedBalance12),
                monthlyNet:
                    '${monthlyNet >= 0 ? '+' : ''}${formatCurrency.format(monthlyNet)}',
              ),
              const SizedBox(height: 12),
              // ── Stat tiles ──
              Row(
                children: [
                  _SummaryChip(
                    icon: Icons.trending_up_rounded,
                    label: 'Monthly net',
                    value:
                        '${monthlyNet >= 0 ? '+' : ''}${formatCurrency.format(monthlyNet)}',
                    bg: AppTheme.lime,
                    fg: AppTheme.ink,
                  ),
                  const SizedBox(width: 12),
                  _SummaryChip(
                    icon: Icons.calendar_today_rounded,
                    label: isPositiveNetFlow ? 'On track' : 'Shortfall',
                    value: formatCurrency.format(projectedBalance12),
                    bg: context.soft,
                    fg: context.onSoft,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Projection Chart ──
              Text('Projected balance',
                  style: Theme.of(context).textTheme.titleLarge),
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
                          _LegendDot(color: context.accent, label: 'Expected'),
                          const SizedBox(width: 16),
                          _LegendDot(
                              color: context.fgFaint, label: 'Range'),
                          if (hasGoal) ...[
                            const SizedBox(width: 16),
                            _LegendDot(
                                color: _goalLine(context),
                                label: 'Goal target'),
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
                                color: context.border,
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
                                        style: GoogleFonts.urbanist(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: context.fgFaint));
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
                                      final futureDate = AppCalendar.addMonthsClamped(
                                          DateTime.now(), month);
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Text(
                                          month == 0
                                              ? 'Now'
                                              : DateFormat.MMM()
                                                  .format(futureDate),
                                          style: GoogleFonts.urbanist(
                                              color: context.fgFaint,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11),
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
                                tooltipBgColor: AppTheme.ink,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final labels = [
                                      'Expected',
                                      if (hasGoal) 'Goal',
                                      'Low',
                                      'High'
                                    ];
                                    final label = labels[spot.barIndex];
                                    return LineTooltipItem(
                                      '${formatCurrency.format(spot.y)}\n$label — Mo ${spot.x.toInt()}',
                                      GoogleFonts.urbanist(
                                        color: AppTheme.white,
                                        fontWeight: FontWeight.w700,
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
                                color: context.accent,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      context.accent.withValues(alpha: 0.22),
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
                                  color: _goalLine(context),
                                  barWidth: 2.5,
                                  isStrokeCapRound: true,
                                  dashArray: [6, 4],
                                  dotData: const FlDotData(show: false),
                                ),
                              // Pessimistic / optimistic band
                              for (final band in [lowSpots, highSpots])
                                LineChartBarData(
                                  spots: band,
                                  isCurved: true,
                                  color: context.fgFaint,
                                  barWidth: 1.5,
                                  dashArray: [2, 4],
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
              Text('Monthly breakdown',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Based on your transaction history',
                style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.fgMuted),
              ),
              const SizedBox(height: 12),
              _BreakdownCard(
                icon: Icons.arrow_downward_rounded,
                chipBg: AppTheme.lime,
                chipFg: AppTheme.ink,
                label: 'Avg monthly income',
                computed: avgIncome,
                current: effectiveIncome,
                formatCurrency: formatCurrency,
              ),
              const SizedBox(height: 8),
              _BreakdownCard(
                icon: Icons.arrow_upward_rounded,
                chipBg: context.cta,
                chipFg: context.onCta,
                label: 'Avg monthly expenses',
                computed: avgExpense,
                current: effectiveExpense,
                formatCurrency: formatCurrency,
              ),
              const SizedBox(height: 24),

              // ── Simulation Sliders ──
              Text('Adjust forecast',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Drag sliders to simulate "what if" scenarios',
                style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.fgMuted),
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
                        color: context.accent,
                        onChanged: (val) =>
                            setState(() => _incomeOverride = val),
                        formatCurrency: formatCurrency,
                      ),
                      Divider(height: 28, color: context.border),
                      _ForecastSlider(
                        label: 'Monthly Expenses',
                        subtext: 'Rent, bills, groceries, etc.',
                        value: effectiveExpense,
                        min: 0,
                        max: (avgExpense * 3).clamp(10000, 500000),
                        color: context.fg,
                        onChanged: (val) =>
                            setState(() => _expenseOverride = val),
                        formatCurrency: formatCurrency,
                      ),
                      Divider(height: 28, color: context.border),
                      _ForecastSlider(
                        label: 'Extra Savings',
                        subtext: 'Additional monthly investment',
                        value: _extraSavings,
                        min: 0,
                        max: (avgIncome * 0.5).clamp(5000, 100000),
                        color: context.isDark
                            ? AppTheme.lavender
                            : AppTheme.blue.withValues(alpha: 0.55),
                        onChanged: (val) =>
                            setState(() => _extraSavings = val),
                        formatCurrency: formatCurrency,
                      ),
                      Divider(height: 28, color: context.border),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Expected yearly return',
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                              ),
                              Text(
                                  '${(annualReturn * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.urbanist(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: context.accent)),
                            ],
                          ),
                          Text('Growth on money you invest each month',
                              style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: context.fgMuted)),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 8,
                              trackShape: const RoundedRectSliderTrackShape(),
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18),
                              activeTrackColor: context.accent,
                              inactiveTrackColor: context.isDark
                                  ? AppTheme.white.withValues(alpha: 0.12)
                                  : AppTheme.lavender,
                              thumbColor: context.accent,
                              overlayColor:
                                  context.accent.withValues(alpha: 0.12),
                              tickMarkShape: SliderTickMarkShape.noTickMark,
                            ),
                            child: Slider(
                              value: annualReturn * 100,
                              min: 0,
                              max: 20,
                              divisions: 40,
                              onChanged: (v) =>
                                  provider.setExpectedReturn(v / 100),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reset button
              if (_incomeOverride != null ||
                  _expenseOverride != null ||
                  _extraSavings != 0)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _incomeOverride = null;
                        _expenseOverride = null;
                        _extraSavings = 0;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset to Actuals'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.fgMuted,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Growth & uncertainty summary ──
              Text('How this is calculated',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _FactRow(
                          label: 'Based on',
                          value: stats.hasData
                              ? 'last ${stats.monthsUsed} full month${stats.monthsUsed == 1 ? '' : 's'}'
                              : 'no data yet'),
                      _FactRow(
                          label: 'Investing per month',
                          value: formatCurrency
                              .format(avgInvest + _extraSavings)),
                      _FactRow(
                          label: 'Growth in 12 months',
                          value:
                              '${growth12 >= 0 ? '+' : ''}${formatCurrency.format(growth12)}'),
                      _FactRow(
                          label: 'Likely range',
                          value:
                              '${formatCurrency.format(points.last.low)} – ${formatCurrency.format(points.last.high)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Goal ETAs ──
              if (provider.goals.isNotEmpty) ...[
                Text('Goal timeline',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        for (final g in provider.goals)
                          _GoalEtaRow(
                            goal: g,
                            share: ForecastService.splitAcrossGoals(
                                    provider.goals,
                                    monthlyNet > 0 ? monthlyNet : 0)[g.id] ??
                                0,
                            annualReturn: annualReturn,
                            formatCurrency: formatCurrency,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── AI coach suggestion ──
              AiForecastInsightCard(
                buildFacts: () {
                  final b = StringBuffer()
                    ..writeln(
                        'Monthly income ${effectiveIncome.toStringAsFixed(0)}, expenses ${effectiveExpense.toStringAsFixed(0)}, investing ${(avgInvest + _extraSavings).toStringAsFixed(0)}.')
                    ..writeln(
                        'Assumed yearly return ${(annualReturn * 100).toStringAsFixed(1)}%.')
                    ..writeln(
                        '12-month projected balance ${projectedBalance12.toStringAsFixed(0)} (range ${points.last.low.toStringAsFixed(0)} to ${points.last.high.toStringAsFixed(0)}).');
                  final split = ForecastService.splitAcrossGoals(
                      provider.goals, monthlyNet > 0 ? monthlyNet : 0);
                  for (final g in provider.goals) {
                    final m = ForecastService.monthsToGoal(
                        g, split[g.id] ?? 0,
                        annualReturn: annualReturn);
                    b.writeln(
                        'Goal ${g.title}: ${g.savedAmount.toStringAsFixed(0)}/${g.targetAmount.toStringAsFixed(0)}, ${m == null ? 'not reachable at current savings' : m == 0 ? 'reached' : 'reached in ${ForecastService.formatMonths(m)}'}.');
                  }
                  return b.toString();
                },
              ),

              const SizedBox(height: 100),
            ],
          )),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: GoogleFonts.urbanist(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted))),
            Text(value,
                style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.fg)),
          ],
        ),
      );
}

class _GoalEtaRow extends StatelessWidget {
  final FinancialGoal goal;
  final double share;
  final double annualReturn;
  final NumberFormat formatCurrency;
  const _GoalEtaRow({
    required this.goal,
    required this.share,
    required this.annualReturn,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final months = ForecastService.monthsToGoal(goal, share,
        annualReturn: annualReturn);
    final text = months == null
        ? 'Needs more savings'
        : months == 0
            ? 'Reached'
            : ForecastService.formatMonths(months);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${formatCurrency.format(share)}/month allocated',
                    style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted)),
              ],
            ),
          ),
          Text(text,
              style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.accent)),
        ],
      ),
    );
  }
}

class _HeroProjection extends StatelessWidget {
  final String value;
  final String monthlyNet;

  const _HeroProjection({required this.value, required this.monthlyNet});

  @override
  Widget build(BuildContext context) {
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
                child: Text('12-month projection',
                    style: GoogleFonts.urbanist(
                        color: AppTheme.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.urbanist(
                    color: AppTheme.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1.1)),
          ),
          const SizedBox(height: 4),
          Text('$monthlyNet per month',
              style: GoogleFonts.urbanist(
                  color: AppTheme.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.urbanist(
                      fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.65))),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.urbanist(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.fgMuted)),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final IconData icon;
  final Color chipBg;
  final Color chipFg;
  final String label;
  final double computed;
  final double current;
  final NumberFormat formatCurrency;

  const _BreakdownCard({
    required this.icon,
    required this.chipBg,
    required this.chipFg,
    required this.label,
    required this.computed,
    required this.current,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final isAdjusted = (current - computed).abs() > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
            child: Icon(icon, color: chipFg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.fg)),
                if (isAdjusted)
                  Text(
                    'Computed: ${formatCurrency.format(computed)}',
                    style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted),
                  ),
              ],
            ),
          ),
          Text(
            formatCurrency.format(current),
            style: GoogleFonts.urbanist(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.fg,
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
                    style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.fg)),
                Text(subtext,
                    style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted)),
              ],
            ),
            Text(
              formatCurrency.format(value),
              style: GoogleFonts.urbanist(
                  color: context.fg, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: color,
            inactiveTrackColor: context.isDark
                ? AppTheme.white.withValues(alpha: 0.12)
                : AppTheme.lavender,
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

Color _goalLine(BuildContext context) =>
    context.isDark ? AppTheme.lavender : AppTheme.ink;
