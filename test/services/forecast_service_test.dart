import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/models/financial_goal.dart';
import 'package:personal_finance_app/models/transaction.dart';
import 'package:personal_finance_app/services/forecast_service.dart';

Transaction tx(int month, double amt, {bool income = false, bool inv = false}) =>
    Transaction(
      id: '${month}_$amt$income$inv',
      amount: amt,
      date: DateTime(2026, month, 10),
      category: 'x',
      isIncome: income,
      isInvestment: inv,
    );

void main() {
  test('analyze skips current month and caps one-off spike', () {
    final now = DateTime(2026, 6, 15);
    final txs = [
      for (final m in [2, 3, 4, 5]) tx(m, 50000, income: true),
      tx(2, 20000), tx(3, 20000), tx(4, 90000), tx(5, 20000), // spike in April
      tx(6, 1), // current month ignored
    ];
    final s = ForecastService.analyze(txs, now: now);
    expect(s.monthsUsed, 4);
    expect(s.income, closeTo(50000, 0.01));
    expect(s.expense, lessThan(32000)); // spike capped at 1.25 x median
    expect(s.expense, greaterThan(20000));
  });

  test('sip future value matches formula', () {
    expect(ForecastService.sipFutureValue(1000, 0.12, 12),
        closeTo(12682.50, 0.5));
    expect(ForecastService.sipFutureValue(1000, 0, 12), 12000);
  });

  test('projection widens and band is ordered', () {
    final p = ForecastService.projectBalance(
        currentBalance: 1000, monthlyNet: 500, netStdDev: 100, months: 12);
    expect(p.first.expected, 1000);
    expect(p.last.expected, 7000);
    expect(p.last.low, lessThan(p.last.expected));
    expect(p.last.high, greaterThan(p.last.expected));
  });

  test('goal months and required monthly are consistent', () {
    final g = FinancialGoal(id: 'g', title: 't', targetAmount: 12000);
    expect(ForecastService.monthsToGoal(g, 1000), 12);
    expect(ForecastService.monthsToGoal(g, 0), isNull);
    expect(ForecastService.requiredMonthly(g, 12), 1000);
    final withReturn = ForecastService.requiredMonthly(g, 12, annualReturn: 0.12);
    expect(withReturn, lessThan(1000));
  });

  test('split across goals is proportional', () {
    final a = FinancialGoal(id: 'a', title: 'a', targetAmount: 3000);
    final b = FinancialGoal(id: 'b', title: 'b', targetAmount: 1000);
    final m = ForecastService.splitAcrossGoals([a, b], 400);
    expect(m['a'], closeTo(300, 0.001));
    expect(m['b'], closeTo(100, 0.001));
  });
}
