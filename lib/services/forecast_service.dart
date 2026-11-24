import 'dart:math' as math;

import '../models/financial_goal.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';

/// Realistic monthly picture built from recent transaction history.
class MonthlyStats {
  final double income;
  final double expense;
  final double investment;

  /// Standard deviation of monthly net (income - expense - investment).
  /// Drives the pessimistic / optimistic band.
  final double netStdDev;

  /// Number of months the averages are based on (0 = no data).
  final int monthsUsed;

  const MonthlyStats({
    required this.income,
    required this.expense,
    required this.investment,
    required this.netStdDev,
    required this.monthsUsed,
  });

  static const empty = MonthlyStats(
      income: 0, expense: 0, investment: 0, netStdDev: 0, monthsUsed: 0);

  double get net => income - expense - investment;
  bool get hasData => monthsUsed > 0;
}

/// One projected month on the chart.
class ForecastPoint {
  final int month;
  final double low;
  final double expected;
  final double high;
  const ForecastPoint(this.month, this.low, this.expected, this.high);
}

/// Pure maths for the forecast. No Flutter, no I/O, so it is easy to test.
class ForecastService {
  ForecastService._();

  /// Months of history used for averages.
  static const defaultWindow = 6;

  // ───────────────────────── Averages ─────────────────────────

  /// Builds realistic monthly averages:
  ///  * only the last [window] months are used;
  ///  * the current, still-incomplete month is skipped when older months exist;
  ///  * recent months weigh more (weights 1..n);
  ///  * one-off spikes are capped at 1.25x the median month.
  static MonthlyStats analyze(
    List<Transaction> txs, {
    DateTime? now,
    int window = defaultWindow,
  }) {
    if (txs.isEmpty) return MonthlyStats.empty;
    now ??= DateTime.now();

    final byMonth = <int, _Month>{};
    for (final t in txs) {
      final key = t.date.year * 12 + t.date.month;
      final m = byMonth.putIfAbsent(key, () => _Month());
      if (t.isIncome) {
        m.income += t.amount;
      } else if (t.isInvestment) {
        m.investment += t.amount;
      } else {
        m.expense += t.amount;
      }
    }

    final currentKey = now.year * 12 + now.month;
    var keys = byMonth.keys.toList()..sort();
    final complete = keys.where((k) => k < currentKey).toList();
    if (complete.isNotEmpty) keys = complete;
    if (keys.length > window) keys = keys.sublist(keys.length - window);

    final months = keys.map((k) => byMonth[k]!).toList();
    final income = _weighted(months.map((m) => m.income).toList());
    final expense = _weighted(months.map((m) => m.expense).toList());
    final investment = _weighted(months.map((m) => m.investment).toList());

    final nets = months.map((m) => m.income - m.expense - m.investment).toList();
    return MonthlyStats(
      income: income,
      expense: expense,
      investment: investment,
      netStdDev: _stdDev(nets),
      monthsUsed: months.length,
    );
  }

  /// Recency-weighted mean with spike capping (values oldest -> newest).
  static double _weighted(List<double> values) {
    if (values.isEmpty) return 0;
    var v = values;
    if (v.length >= 3) {
      final cap = _median(v) * 1.25;
      if (cap > 0) v = v.map((x) => math.min(x, cap)).toList();
    }
    var sum = 0.0, wsum = 0.0;
    for (var i = 0; i < v.length; i++) {
      final w = (i + 1).toDouble();
      sum += v[i] * w;
      wsum += w;
    }
    return sum / wsum;
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }

  static double _stdDev(List<double> v) {
    if (v.length < 2) return 0;
    final mean = v.reduce((a, b) => a + b) / v.length;
    final variance =
        v.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) / (v.length - 1);
    return math.sqrt(variance);
  }

  // ───────────────────────── Growth maths ─────────────────────────

  /// SIP future value: [monthly] invested at the end of each month for
  /// [months] months at [annualRate] (e.g. 0.10 = 10% a year).
  static double sipFutureValue(
      double monthly, double annualRate, int months) {
    if (months <= 0 || monthly == 0) return 0;
    final r = annualRate / 12;
    if (r == 0) return monthly * months;
    return monthly * ((math.pow(1 + r, months) - 1) / r);
  }

  /// Lump sum compounded monthly.
  static double compound(double principal, double annualRate, int months) {
    if (months <= 0) return principal;
    return principal * math.pow(1 + annualRate / 12, months);
  }

  // ───────────────────────── Balance forecast ─────────────────────────

  /// Month 0..[months] projection of total wealth (cash + invested).
  ///
  /// * cash moves by [monthlyNet] each month (income - expenses - investing);
  /// * [monthlyInvest] (existing + extra SIP) and [investedBase] compound at
  ///   [annualReturn];
  /// * low / high use ±1 std dev of monthly net, widening with sqrt(time).
  static List<ForecastPoint> projectBalance({
    required double currentBalance,
    required double monthlyNet,
    required double netStdDev,
    double investedBase = 0,
    double monthlyInvest = 0,
    double annualReturn = 0,
    int months = 12,
  }) {
    final points = <ForecastPoint>[];
    for (var i = 0; i <= months; i++) {
      final growth = compound(investedBase, annualReturn, i) -
          investedBase +
          sipFutureValue(monthlyInvest, annualReturn, i);
      final expected = currentBalance + monthlyNet * i + growth;
      final spread = netStdDev * math.sqrt(i.toDouble());
      points.add(ForecastPoint(i, expected - spread, expected, expected + spread));
    }
    return points;
  }

  // ───────────────────────── Goals ─────────────────────────

  /// Months until [goal] is reached saving [monthlyAmount] per month at
  /// [annualReturn]. Returns 0 if already reached, null if it never will
  /// within [maxMonths] (or the saving rate is zero or negative).
  static int? monthsToGoal(
    FinancialGoal goal,
    double monthlyAmount, {
    double annualReturn = 0,
    int maxMonths = 600,
  }) {
    final remaining = goal.targetAmount - goal.savedAmount;
    if (remaining <= 0) return 0;
    if (monthlyAmount <= 0) return null;
    final r = annualReturn / 12;
    var balance = goal.savedAmount;
    for (var m = 1; m <= maxMonths; m++) {
      balance = balance * (1 + r) + monthlyAmount;
      if (balance >= goal.targetAmount) return m;
    }
    return null;
  }

  /// Monthly saving needed to hit [goal] in [months] months.
  static double requiredMonthly(
    FinancialGoal goal,
    int months, {
    double annualReturn = 0,
  }) {
    final remaining = goal.targetAmount - goal.savedAmount;
    if (remaining <= 0 || months <= 0) return 0;
    final r = annualReturn / 12;
    final grownSaved = goal.savedAmount * math.pow(1 + r, months);
    final need = goal.targetAmount - grownSaved;
    if (need <= 0) return 0;
    if (r == 0) return need / months;
    return need * r / (math.pow(1 + r, months) - 1);
  }

  /// Splits [monthlyAmount] across unfinished goals in proportion to what each
  /// still needs. Returns goal id -> monthly share.
  static Map<String, double> splitAcrossGoals(
      List<FinancialGoal> goals, double monthlyAmount) {
    final open =
        goals.where((g) => g.targetAmount > g.savedAmount).toList();
    if (open.isEmpty || monthlyAmount <= 0) return {};
    final totalNeed =
        open.fold<double>(0, (s, g) => s + (g.targetAmount - g.savedAmount));
    return {
      for (final g in open)
        g.id: monthlyAmount * (g.targetAmount - g.savedAmount) / totalNeed,
    };
  }

  // ───────────────────────── Bills ─────────────────────────

  static double monthlyBillTotal(List<RecurringBill> bills) =>
      bills.fold<double>(0, (s, b) => s + b.amount);

  /// "3 mo", "1 yr 4 mo", ...
  static String formatMonths(int months) {
    if (months < 12) return '$months mo';
    final y = months ~/ 12, m = months % 12;
    return m == 0 ? '$y yr' : '$y yr $m mo';
  }
}

class _Month {
  double income = 0, expense = 0, investment = 0;
}
