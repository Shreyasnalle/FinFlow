import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_calendar.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/transfer_sheet.dart';
import 'assets_screen.dart';
import 'recurring_bills_screen.dart';
import 'transaction_screen.dart';
import 'settings_screen.dart';
import '../widgets/tap_scale.dart';
import '../widgets/smooth_wheel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  AppCalendar _cal = AppCalendar();
  HomePeriod _period = HomePeriod.all;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The app can stay open past midnight / month end: re-read the real date.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _syncClock());
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncClock();
  }

  void _syncClock() {
    final n = DateTime.now();
    if (!mounted || AppCalendar.sameDay(n, _cal.now)) return;
    setState(() => _cal = AppCalendar(n));
  }

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

  void _openAll(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const TransactionScreen()));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final stats = provider.monthlyStats;
    final monthlyNet = stats.hasData ? stats.income - stats.expense : 0.0;

    String initials = "AR";
    if (provider.userName.isNotEmpty) {
      final parts = provider.userName.split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = provider.userName
            .substring(0, provider.userName.length >= 2 ? 2 : 1)
            .toUpperCase();
      }
    }
    final firstName = provider.userName.split(' ').first;

    List<FlSpot> spots = [];
    final reversedList = provider.transactions.reversed.toList();
    for (int i = 0; i < reversedList.length && i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), reversedList[i].amount));
    }
    if (spots.isEmpty) spots = [const FlSpot(0, 0)];

    final range = _cal.rangeFor(_period);
    final periodTxs = provider.transactions
        .where((t) => range == null || range.contains(t.date))
        .toList();
    var income = 0.0;
    var spent = 0.0;
    for (final t in periodTxs) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        spent += t.amount;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: SmoothWheel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_greeting()},\n$firstName!',
                      style: GoogleFonts.urbanist(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: context.fg),
                    ),
                  ),
                  TapScale(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.lavender,
                      foregroundColor: AppTheme.ink,
                      child: Text(initials,
                          style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Overview
              _SectionHeader(
                  title: 'Overview',
                  action: 'See all',
                  onAction: () => _openAll(context)),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in HomePeriod.values)
                      _Pill(
                          label: _cal.labelFor(p),
                          selected: _period == p,
                          onTap: () => setState(() => _period = p)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hero balance card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: context.hero,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total balance',
                            style: GoogleFonts.urbanist(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.white.withValues(alpha: 0.85))),
                        TapScale(
                          onTap: () => _openAll(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                                color: AppTheme.lime, shape: BoxShape.circle),
                            child: const Icon(Icons.north_east,
                                size: 18, color: AppTheme.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCurrency.format(provider.currentBalance),
                        style: GoogleFonts.urbanist(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: AppTheme.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Net worth in cash',
                        style: GoogleFonts.urbanist(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 56,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: AppTheme.lime,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.lime.withValues(alpha: 0.25),
                                    Colors.transparent
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Income / Expense tiles
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      background: context.soft,
                      foreground: context.onSoft,
                      label: 'Income',
                      value: formatCurrency.format(income),
                      caption: _cal.captionFor(_period),
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      background: context.surface,
                      foreground: context.fg,
                      label: 'Expenses',
                      value: formatCurrency.format(spent),
                      caption: _cal.captionFor(_period),
                      icon: Icons.north_east,
                      outlined: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Shortcuts: assets and recurring bills
              _ShortcutTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'My assets',
                subtitle: provider.assets.isEmpty
                    ? 'Track what you own'
                    : formatCurrency.format(provider.assets.fold<double>(0, (sum, a) => sum + a.value)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetsScreen())),
              ),
              const SizedBox(height: 12),
              _ShortcutTile(
                icon: Icons.receipt_long_outlined,
                title: 'Recurring bills',
                subtitle: provider.bills.isEmpty
                    ? 'Rent, subscriptions and more'
                    : '${provider.bills.length} scheduled',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringBillsScreen())),
              ),
              const SizedBox(height: 12),

              // Transfer row
              TapScale(
                onTap: () => _showTransfer(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                            color: AppTheme.lime, shape: BoxShape.circle),
                        child: const Icon(Icons.swap_horiz,
                            color: AppTheme.ink, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Transfer funds',
                            style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.fg)),
                      ),
                      Icon(Icons.chevron_right, color: context.fgFaint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Recent transactions
              // Primary CTA pill
              TapScale(
                onTap: () => _showAddTransaction(context),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                      color: context.cta,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: context.onCta, size: 20),
                      const SizedBox(width: 8),
                      Text('Add transaction',
                          style: GoogleFonts.urbanist(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.onCta)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(height: 28),

              _SectionHeader(
                  title: 'Recent transactions',
                  action: 'See all',
                  onAction: () => _openAll(context)),
              const SizedBox(height: 14),

              if (periodTxs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusTile)),
                  child: Center(
                    child: Text(
                      provider.transactions.isEmpty
                          ? 'No transactions yet. Tap "Add transaction" to get started!'
                          : 'No transactions for ${_cal.labelFor(_period)}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                          color: context.fgMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                )
              else
                ...periodTxs.take(5).map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusTile),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.isIncome
                                  ? AppTheme.lime
                                  : AppTheme.lavender,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              t.isIncome ? Icons.south_west : Icons.north_east,
                              color: AppTheme.ink,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.category,
                                    style: GoogleFonts.urbanist(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: context.fg)),
                                const SizedBox(height: 2),
                                Text(DateFormat.yMMMd().format(t.date),
                                    style: GoogleFonts.urbanist(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: context.fgMuted)),
                              ],
                            ),
                          ),
                          Text(
                            '${t.isIncome ? '+' : '-'}${formatCurrency.format(t.amount)}',
                            style: GoogleFonts.urbanist(
                              color: t.isIncome ? context.fg : context.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 28),

              // Forecast snapshot
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: context.soft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppTheme.lime,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt,
                                  color: AppTheme.ink, size: 16),
                              const SizedBox(width: 4),
                              Text('Forecast',
                                  style: GoogleFonts.urbanist(
                                      color: AppTheme.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
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
                            Text('Projected in 30 days',
                                style: GoogleFonts.urbanist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.onSoft
                                        .withValues(alpha: 0.65))),
                            const SizedBox(height: 4),
                            Text(
                              formatCurrency.format(provider.currentBalance + monthlyNet),
                              style: GoogleFonts.urbanist(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: context.onSoft),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(monthlyNet >= 0 ? 'Est. savings' : 'Est. shortfall',
                                style: GoogleFonts.urbanist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.onSoft
                                        .withValues(alpha: 0.65))),
                            const SizedBox(height: 4),
                            Text(
                              '${monthlyNet >= 0 ? '+' : '-'}${formatCurrency.format(monthlyNet.abs())}',
                              style: GoogleFonts.urbanist(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.onSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Based on average recurring income and fixed expenses.',
                      style: GoogleFonts.urbanist(
                          fontSize: 11,
                          color: context.onSoft.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const SizedBox(height: 80),
            ],
          )),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: GoogleFonts.urbanist(
                fontSize: 20, fontWeight: FontWeight.w700, color: context.fg)),
        if (action != null)
          TapScale(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.fg,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill(
      {required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime : context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: GoogleFonts.urbanist(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.ink : context.fgMuted,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color background;
  final Color foreground;
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool outlined;

  const _StatTile({
    required this.background,
    required this.foreground,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: outlined ? Border.all(color: context.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground.withValues(alpha: 0.7))),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: AppTheme.lime, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: AppTheme.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.urbanist(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: foreground)),
          ),
          const SizedBox(height: 2),
          Text(caption,
              style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ShortcutTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusTile),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.ink, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w700, color: context.fg)),
                  Text(subtitle, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w500, color: context.fgMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.fgFaint),
          ],
        ),
      ),
    );
  }
}
