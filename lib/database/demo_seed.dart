import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../models/asset.dart';
import '../models/financial_goal.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';
import 'finance_repository.dart';

/// Demo account: "Demo User", PIN 1234, with [months] months of believable
/// history ending today.
///
/// The data is generated, not random per run: a fixed-seed generator means the
/// same numbers every time, so the app can be checked against known values.
/// The story it tells: an annual appraisal, a job switch with a bigger salary
/// and a new flat (deposit, furniture), seasonal electricity bills, festive
/// shopping spikes, trips, irregular freelance income, a medical bill, and a
/// few months where spending outruns income.
class DemoSeed {
  DemoSeed._();

  static const userName = 'Demo User';
  static const mobile = '9876543210';
  static const age = '29';
  static const profession = 'Software Engineer';
  static const pin = '1234';
  static const months = 36;

  /// Offered in debug builds, or in a release build made with
  /// `--dart-define=DEMO_USER=true`. A normal release never ships fake data.
  static const bool enabled = kDebugMode || bool.fromEnvironment('DEMO_USER');

  /// Fills the database with demo data (profile excluded) in one transaction.
  static void apply(FinanceRepository repo, DateTime now) =>
      repo.transaction(() => _Builder(repo, now).build());
}

/// Park-Miller generator. Only small integer math, so results are identical on
/// every platform (including web, where integers are 53-bit).
class _Rng {
  _Rng(this._s);
  int _s;

  double next() {
    _s = (_s * 48271) % 2147483647;
    return _s / 2147483647;
  }

  double range(double a, double b) => a + (b - a) * next();
  int rint(int a, int b) => a + (next() * (b - a + 1)).floor();
  bool chance(double p) => next() < p;
  T pick<T>(List<T> xs) => xs[rint(0, xs.length - 1)];
}

class _Builder {
  _Builder(this.repo, this.now) : r = _Rng(20261125);

  final FinanceRepository repo;
  final DateTime now;
  final _Rng r;

  int _n = 0;
  double _mf = 0, _stocks = 0, _gold = 0;

  static const _emergency = 'demo-goal-emergency';
  static const _laptop = 'demo-goal-laptop';
  static const _goa = 'demo-goal-goa';
  static const _europe = 'demo-goal-europe';

  /// Electricity bills swing with the seasons (AC in summer, little in winter).
  static const _electricity = {
    1: 0.8, 2: 0.85, 3: 1.3, 4: 2.0, 5: 2.4, 6: 2.1,
    7: 1.4, 8: 1.3, 9: 1.2, 10: 1.0, 11: 0.85, 12: 0.8,
  };

  /// Festive / sale-season shopping multiplier.
  static const _festive = {10: 2.2, 11: 1.7, 12: 1.5, 1: 1.2};

  double _round(double v, [int to = 1]) => (v / to).round() * to.toDouble();

  DateTime _at(DateTime month, int day, [int? hour]) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, day.clamp(1, last),
        hour ?? r.rint(8, 21), r.rint(0, 59));
  }

  void tx(
    DateTime when,
    String category,
    double amount, {
    bool income = false,
    bool invest = false,
    String note = '',
  }) {
    if (when.isAfter(now) || amount <= 0) return; // nothing dated in the future
    repo.addTransaction(Transaction(
      id: 'demo-${_n++}',
      amount: amount,
      date: when,
      category: category,
      note: note,
      isIncome: income,
      isInvestment: invest,
    ));
    if (invest) {
      switch (category) {
        case 'SIP' || 'ELSS':
          _mf += amount;
        case 'Stocks':
          _stocks += amount;
        case 'Gold':
          _gold += amount;
      }
    }
  }

  void goalSave(String goalId, DateTime when, double amount) {
    if (when.isAfter(now)) return;
    repo.saveToGoal(goalId, amount, 'demo-${_n++}', at: when);
  }

  void build() {
    repo.addGoal(FinancialGoal(
        id: _emergency, title: 'Emergency fund', targetAmount: 400000));
    repo.addGoal(
        FinancialGoal(id: _laptop, title: 'New laptop', targetAmount: 90000));
    repo.addGoal(
        FinancialGoal(id: _goa, title: 'Goa trip', targetAmount: 60000));
    repo.addGoal(
        FinancialGoal(id: _europe, title: 'Europe trip', targetAmount: 250000));

    for (var i = 0; i < DemoSeed.months; i++) {
      _month(i, DateTime(now.year, now.month - (DemoSeed.months - 1 - i)));
    }

    _budgets();
    _bills();
    _assets();
  }

  // ───────────────────────────── One month ─────────────────────────────

  void _month(int i, DateTime m) {
    final cm = m.month;
    final infl = math.pow(1.055, i / 12).toDouble(); // ~5.5% a year
    final softInfl = math.sqrt(infl);

    // ── Income ──
    final salary = i < 11 ? 90000.0 : (i < 22 ? 102000.0 : 132000.0);
    tx(_at(m, r.rint(1, 3), 10), 'Salary', salary,
        income: true, note: 'Monthly salary');
    if (i == 0) {
      tx(_at(m, 1, 11), 'Other', 60000,
          income: true, note: 'Savings carried over');
    }
    if (cm == 4) {
      tx(_at(m, r.rint(8, 14), 11), 'Salary',
          _round(salary * r.range(0.7, 1.2), 100),
          income: true, note: 'Annual bonus');
    }
    if (cm % 3 == 0) {
      tx(_at(m, r.rint(14, 20), 11), 'Salary',
          _round(salary * r.range(0.04, 0.09), 100),
          income: true, note: 'Quarterly variable pay');
    }
    if (i == 22) {
      tx(_at(m, 5, 12), 'Salary', 60000,
          income: true, note: 'Joining bonus');
      tx(_at(m, 9, 12), 'Other', 38000,
          income: true, note: 'Full & final settlement');
    }
    final freelanceNote = r.pick(const [
      'Website project', 'Logo & branding', 'Consulting call',
      'App bug-fix retainer', 'Landing page build',
    ]);
    if (r.chance(i < 12 ? 0.3 : 0.5)) {
      tx(_at(m, r.rint(5, 26)), 'Freelance', _round(r.range(6500, 30000), 500),
          income: true, note: freelanceNote);
    }
    if (i == 16) {
      tx(_at(m, 18), 'Freelance', 52000, income: true, note: 'Mobile app MVP');
    }
    if (cm % 3 == 0) {
      tx(_at(m, 28, 10), 'Interest', _round(r.range(2200, 3400) + i * 35, 10),
          income: true, note: 'FD interest');
    }
    if (cm == 5 || cm == 11) {
      tx(_at(m, r.rint(10, 24)), 'Dividends', _round(r.range(1400, 5200), 10),
          income: true, note: 'Dividend payout');
    }
    if (cm == 8) {
      tx(_at(m, 14, 12), 'Gift', _round(r.range(3000, 7500), 500),
          income: true, note: 'Birthday gift');
      tx(_at(m, 22, 12), 'Refund', _round(r.range(8400, 19000), 100),
          income: true, note: 'Income tax refund');
    } else if (r.chance(0.12)) {
      tx(_at(m, r.rint(3, 26)), 'Refund', _round(r.range(600, 4800), 10),
          income: true, note: 'Order refund');
    }

    // ── Housing & bills ──
    final rent = i < 11 ? 22000.0 : (i < 22 ? 24000.0 : 32000.0);
    tx(_at(m, r.rint(3, 6), 9), 'Rent', rent, note: 'Apartment rent');
    if (i == 22) {
      tx(_at(m, 2, 15), 'Rent', 96000, note: 'Security deposit (new flat)');
      tx(_at(m, 3, 16), 'Other', 16000, note: 'Broker fee & movers');
    }
    final elec = 1900 *
        _electricity[cm]! *
        r.range(0.85, 1.15) *
        (i >= 22 ? 1.2 : 1.0);
    tx(_at(m, r.rint(12, 16)), 'Utilities', _round(elec), note: 'Electricity bill');
    tx(_at(m, 18), 'Utilities', i < 14 ? 599 : 749, note: 'Mobile recharge');
    tx(_at(m, 10), 'Utilities', i < 18 ? 1099 : 1179, note: 'Broadband');
    if (i.isEven) {
      tx(_at(m, r.rint(6, 24)), 'Utilities', _round(r.range(920, 1120)),
          note: 'Cooking gas cylinder');
    }

    // ── Subscriptions ──
    tx(_at(m, 14), 'Subscriptions', i < 12 ? 499 : 649, note: 'Netflix');
    if (i >= 5) tx(_at(m, 18), 'Subscriptions', 119, note: 'Spotify');
    if (i >= 8) tx(_at(m, 20), 'Subscriptions', 1500, note: 'Gym membership');
    if (cm == 7) {
      tx(_at(m, 9), 'Subscriptions', 1499, note: 'Amazon Prime (annual)');
    }

    // ── Everyday spending ──
    final groceries = 7600 *
        infl *
        r.range(0.88, 1.15) *
        (cm == 10 || cm == 11 ? 1.18 : 1.0);
    final trips = r.rint(4, 6);
    for (var k = 0; k < trips; k++) {
      final day = ((k + 0.5) * 30 / trips).round() + r.rint(-1, 1);
      tx(_at(m, day), 'Groceries', _round(groceries / trips * r.range(0.7, 1.35)),
          note: r.pick(const [
            'BigBasket order', 'Weekly vegetables & fruits', 'Supermarket run',
            'Milk, bread & staples', 'Blinkit top-up',
          ]));
    }
    for (var k = r.rint(6, 11); k > 0; k--) {
      tx(_at(m, r.rint(1, 28)), 'Food', _round(r.range(180, 720) * softInfl),
          note: r.pick(const [
            'Swiggy', 'Zomato', 'Office lunch', 'Chai & snacks',
            'Lunch with team',
          ]));
    }
    for (var k = r.rint(2, 4) + (cm == 12 ? 2 : 0); k > 0; k--) {
      tx(_at(m, r.rint(1, 28), r.rint(19, 22)), 'Dining',
          _round(r.range(700, 2600) * infl),
          note: r.pick(const [
            'Dinner out', 'Weekend brunch', 'Birthday dinner', 'Team dinner',
          ]));
    }
    for (var k = r.rint(6, 11); k > 0; k--) {
      tx(_at(m, r.rint(1, 28)), 'Transport', _round(r.range(120, 520) * softInfl),
          note: r.pick(const ['Uber', 'Ola', 'Rapido', 'Auto fare']));
    }
    tx(_at(m, 2), 'Transport', 1000, note: 'Metro card recharge');
    if (cm == 2 || cm == 8) {
      tx(_at(m, r.rint(8, 20)), 'Transport', 2400, note: 'Bike service');
    }
    for (var k = 0; k < 2; k++) {
      tx(_at(m, k == 0 ? r.rint(3, 10) : r.rint(17, 26)), 'Fuel',
          _round(r.range(700, 1100) * math.pow(1.03, i / 12).toDouble()),
          note: 'Petrol');
    }

    // ── Shopping & lifestyle ──
    final festive = _festive[cm] ?? 1.0;
    for (var k = r.rint(2, 4); k > 0; k--) {
      tx(_at(m, r.rint(1, 28)), 'Shopping',
          _round(r.range(400, 2800) * festive * infl),
          note: r.pick(const [
            'Amazon order', 'Myntra', 'Flipkart', 'Home essentials',
            'Decathlon',
          ]));
    }
    if (cm == 10) {
      tx(_at(m, r.rint(8, 18)), 'Shopping', _round(r.range(9000, 22000), 10),
          note: 'Festive sale: appliances');
    }
    if (i == 17) tx(_at(m, 11), 'Shopping', 9990, note: 'Headphones');
    if (i == 23) tx(_at(m, 6), 'Shopping', 38500, note: 'Furniture (new flat)');
    if (i == 30) tx(_at(m, 12), 'Shopping', 52999, note: 'New phone');

    for (var k = r.rint(1, 3); k > 0; k--) {
      tx(_at(m, r.rint(1, 28), r.rint(17, 22)), 'Entertainment',
          _round(r.range(300, 1100) * softInfl),
          note: r.pick(const ['Movie night', 'PVR tickets', 'Bowling', 'Gaming']));
    }
    if (r.chance(0.2)) {
      tx(_at(m, r.rint(5, 26), 19), 'Entertainment',
          _round(r.range(2500, 7500), 50),
          note: r.pick(const ['Concert tickets', 'Comedy show', 'Cricket match']));
    }
    for (var k = r.rint(1, 3); k > 0; k--) {
      tx(_at(m, r.rint(1, 28)), 'Other', _round(r.range(300, 2500)),
          note: r.pick(const [
            'Haircut', 'Gift for friend', 'Donation', 'Laundry', 'Courier',
            'Pet supplies',
          ]));
    }

    // ── Health, insurance, learning ──
    if (r.chance(0.35)) {
      tx(_at(m, r.rint(2, 27)), 'Health', _round(r.range(400, 3200)),
          note: r.pick(const [
            'Pharmacy', 'Doctor consultation', 'Lab tests', 'Eye check-up',
          ]));
    }
    if (i == 17) {
      tx(_at(m, 9), 'Health', 18500, note: 'Dental treatment');
      tx(_at(m, 21), 'Health', 6200, note: 'Full body check-up');
    }
    if (cm == 1) {
      tx(_at(m, 12), 'Insurance',
          _round(14800 * math.pow(1.08, i / 12).toDouble(), 10),
          note: 'Health insurance premium');
    }
    if (cm == 7) {
      tx(_at(m, 20), 'Insurance', 11200, note: 'Term life premium');
    }
    if (r.chance(0.15)) {
      tx(_at(m, r.rint(3, 26)), 'Education', _round(r.range(1499, 7999)),
          note: r.pick(const ['Online course', 'Books', 'Udemy bundle']));
    }
    if (i == 9) tx(_at(m, 15), 'Education', 32000, note: 'Cloud certification');

    // ── Travel ──
    if (cm == 5 && r.chance(0.8)) {
      tx(_at(m, r.rint(10, 24)), 'Travel', _round(r.range(32000, 55000), 100),
          note: 'Summer holiday');
    }
    if ((cm == 10 || cm == 11) && r.chance(0.5)) {
      tx(_at(m, r.rint(2, 15)), 'Travel', _round(r.range(8000, 14500), 50),
          note: 'Flights home (Diwali)');
    }
    if (cm == 12 && r.chance(0.7)) {
      tx(_at(m, r.rint(20, 28)), 'Travel', _round(r.range(26000, 45000), 100),
          note: 'New Year getaway');
    }
    if (r.chance(0.12)) {
      tx(_at(m, r.rint(4, 26)), 'Travel', _round(r.range(3500, 9000), 50),
          note: 'Weekend getaway');
    }

    // ── Investing ──
    final sip = i < 11 ? 8000.0 : (i < 22 ? 12000.0 : 18000.0);
    if (i != 22) {
      tx(_at(m, r.rint(2, 5), 10), 'SIP', sip,
          invest: true, note: 'Index fund SIP');
    }
    if (cm == 3) {
      tx(_at(m, r.rint(15, 28)), 'ELSS', _round(r.range(20000, 40000), 500),
          invest: true, note: 'Tax-saving ELSS');
    }
    if (r.chance(0.15)) {
      tx(_at(m, r.rint(5, 25)), 'Stocks', _round(r.range(8000, 35000), 500),
          invest: true, note: 'Direct equity');
    }
    if (cm == 10) {
      tx(_at(m, r.rint(10, 24)), 'Gold', _round(r.range(15000, 30000), 500),
          invest: true, note: 'Digital gold (Dhanteras)');
    }

    // ── Goal savings (real goal-saving path: balance and goals stay in sync) ──
    final emergency = i < 11 ? 4000.0 : (i < 22 ? 6000.0 : 9000.0);
    if (!r.chance(0.15)) goalSave(_emergency, _at(m, r.rint(8, 12), 10), emergency);
    if (i < 10) goalSave(_laptop, _at(m, r.rint(6, 9), 10), 9000);
    if (i >= 12 && i < 22) goalSave(_goa, _at(m, r.rint(15, 20), 10), 5400);
    if (i >= 18 && !r.chance(0.2)) {
      goalSave(_europe, _at(m, r.rint(20, 25), 10), 7500);
    }
  }

  // ───────────────────────────── Budgets, bills, assets ─────────────────────────────

  void _budgets() {
    repo.setBudget('Groceries', 11000);
    repo.setBudget('Food', 5000);
    repo.setBudget('Dining', 4500);
    repo.setBudget('Transport', 4000);
    repo.setBudget('Shopping', 7000);
    repo.setBudget('Entertainment', 3000);
    repo.setBudget('Utilities', 6000);
  }

  /// Next calendar occurrence of [day] strictly after today.
  DateTime _next(int day) {
    final today = DateTime(now.year, now.month, now.day);
    var d = DateTime(now.year, now.month, day);
    if (!d.isAfter(today)) d = DateTime(now.year, now.month + 1, day);
    return d;
  }

  void _bills() {
    final bills = [
      ('rent', 'Rent', 32000.0, 5),
      ('internet', 'Internet', 1179.0, 10),
      ('netflix', 'Netflix', 649.0, 14),
      ('spotify', 'Spotify', 119.0, 18),
      ('gym', 'Gym membership', 1500.0, 20),
    ];
    for (final (id, name, amount, day) in bills) {
      repo.addBill(RecurringBill(
          id: 'demo-bill-$id', name: name, amount: amount, dueDate: _next(day)));
    }
  }

  void _assets() {
    repo.addAsset(Asset(id: 'demo-asset-fd', name: 'Fixed deposit', value: 300000));
    repo.addAsset(Asset(
        id: 'demo-asset-mf',
        name: 'Mutual funds',
        value: _round(_mf * 1.09, 100)));
    repo.addAsset(Asset(
        id: 'demo-asset-stocks',
        name: 'Stocks',
        value: _round(_stocks * 1.14, 100)));
    repo.addAsset(Asset(
        id: 'demo-asset-gold',
        name: 'Gold',
        value: _round(95000 + _gold * 1.3, 100)));
    repo.addAsset(Asset(id: 'demo-asset-epf', name: 'EPF', value: 312000));
  }
}
