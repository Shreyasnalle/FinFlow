import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/database/app_database.dart';
import 'package:personal_finance_app/database/demo_seed.dart';
import 'package:personal_finance_app/database/finance_repository.dart';
import 'package:personal_finance_app/providers/finance_provider.dart';
import 'package:personal_finance_app/services/forecast_service.dart';

void main() {
  final now = DateTime(2026, 11, 25, 12);
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = FinanceRepository(db);
  });
  tearDown(() => db.close());

  test('covers 36 months ending in the current month, nothing in the future', () {
    DemoSeed.apply(repo, now);
    final months = repo.loadMonthlySummary();
    expect(months, hasLength(36));
    expect(months.first.monthKey, '2023-12');
    expect(months.last.monthKey, '2026-11');
    expect(repo.loadTransactions().every((t) => !t.date.isAfter(now)), isTrue);
    expect(repo.loadTransactions().length, greaterThan(1200));
  });

  test('looks like a real life, not a straight line', () {
    DemoSeed.apply(repo, now);
    final months = repo.loadMonthlySummary();
    final nets = months.map((m) => m.net).toList();
    final mean = nets.reduce((a, b) => a + b) / nets.length;
    final sd = math.sqrt(
        nets.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) / nets.length);

    expect(sd, greaterThan(30000), reason: 'monthly net should swing widely');
    expect(nets.where((n) => n < 0).length, inInclusiveRange(8, 20),
        reason: 'some lean months');
    expect(nets.where((n) => n > 0).length, greaterThan(12));

    final spend = months.map((m) => m.expense).toList();
    expect(spend.reduce(math.max) / spend.reduce(math.min), greaterThan(2.5),
        reason: 'big one-off months (new flat, trips, festive shopping)');

    // Three salary levels: appraisal, then a job switch.
    final salaries = repo
        .loadTransactions()
        .where((t) => t.category == 'Salary' && t.note == 'Monthly salary')
        .map((t) => t.amount)
        .toSet();
    expect(salaries, {90000.0, 102000.0, 132000.0});

    // Seasonality: summer electricity is much higher than winter.
    double elec(String month) => repo
        .loadTransactions()
        .where((t) => t.note == 'Electricity bill' && t.date.month == int.parse(month))
        .fold<double>(0, (s, t) => s + t.amount);
    expect(elec('5'), greaterThan(elec('12') * 1.8));
  });

  test('stays financially plausible: cash never goes negative', () {
    DemoSeed.apply(repo, now);
    var running = 0.0, lowest = double.infinity;
    for (final m in repo.loadMonthlySummary()) {
      running += m.net;
      lowest = math.min(lowest, running);
    }
    expect(lowest, greaterThan(0));
    expect(repo.balance(), closeTo(running, 0.01));
    expect(repo.balance(), inInclusiveRange(200000, 900000));
  });

  test('goal progress equals the savings transactions behind it', () {
    DemoSeed.apply(repo, now);
    final goals = repo.loadGoals();
    expect(goals.map((g) => g.title),
        ['Emergency fund', 'New laptop', 'Goa trip', 'Europe trip']);

    final saved = goals.fold<double>(0, (s, g) => s + g.savedAmount);
    final fromTxns = repo
        .loadTransactions()
        .where((t) => t.category.startsWith('Savings: '))
        .fold<double>(0, (s, t) => s + t.amount);
    expect(saved, closeTo(fromTxns, 0.01));

    final status = {
      for (final r in db.raw.select('SELECT title, status FROM goals'))
        r['title']: r['status']
    };
    expect(status['New laptop'], 'completed');
    expect(status['Emergency fund'], 'active');
  });

  test('budgets exist and are sometimes exceeded', () {
    DemoSeed.apply(repo, now);
    expect(repo.loadBudgets(), hasLength(7));
    final over = db.raw
        .select('SELECT count(*) AS n FROM v_budget_status WHERE over_minor > 0')
        .first['n'] as int;
    expect(over, greaterThan(10));
  });

  test('bills are all still in the future, so none are auto-charged at start', () {
    DemoSeed.apply(repo, now);
    final bills = repo.loadBills();
    expect(bills.map((b) => b.name),
        ['Rent', 'Internet', 'Netflix', 'Spotify', 'Gym membership']);
    expect(bills.every((b) => b.dueDate.isAfter(now)), isTrue);
    expect(repo.processDueBills(now), 0);
  });

  test('assets are present and sensible', () {
    DemoSeed.apply(repo, now);
    final assets = repo.loadAssets();
    expect(assets.map((a) => a.name),
        ['Fixed deposit', 'Mutual funds', 'Stocks', 'Gold', 'EPF']);
    expect(assets.every((a) => a.value > 0), isTrue);
  });

  test('is deterministic: same day, same numbers', () {
    DemoSeed.apply(repo, now);
    String fingerprint(FinanceRepository r) => r
        .loadTransactions()
        .map((t) => '${t.date.toIso8601String()}|${t.category}|${t.amount}')
        .join('\n');
    final first = fingerprint(repo);

    final db2 = AppDatabase.inMemory();
    addTearDown(db2.close);
    final repo2 = FinanceRepository(db2);
    DemoSeed.apply(repo2, now);
    expect(fingerprint(repo2), first);
  });

  test('works for any "today", including month ends and the 1st', () {
    for (final day in [
      DateTime(2027, 1, 31, 23),
      DateTime(2026, 3, 1, 0, 5),
      DateTime(2026, 12, 31, 12),
      DateTime(2028, 2, 29, 12),
    ]) {
      final d = AppDatabase.inMemory();
      final r = FinanceRepository(d);
      DemoSeed.apply(r, day);
      expect(r.loadTransactions().every((t) => !t.date.isAfter(day)), isTrue,
          reason: '$day');
      expect(r.loadMonthlySummary().length, inInclusiveRange(35, 36),
          reason: '$day');
      expect(r.loadBills().every((b) => b.dueDate.isAfter(day)), isTrue,
          reason: '$day');
      d.close();
    }
  });

  test('forecast has six full months to work from', () {
    DemoSeed.apply(repo, now);
    final s = ForecastService.analyze(repo.loadTransactions(), now: now);
    expect(s.monthsUsed, 6);
    expect(s.income, greaterThan(s.expense));
    expect(s.netStdDev, greaterThan(0));
  });

  group('demo account', () {
    test('createDemoAccount makes Demo User with PIN 1234 and signs in', () async {
      final provider = FinanceProvider(repo);
      await provider.init();
      expect(provider.hasProfile, isFalse);

      expect(await provider.createDemoAccount(), isTrue);
      expect(provider.userName, DemoSeed.userName);
      expect(provider.hasProfile, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.checkPin('1234'), isTrue);
      expect(provider.checkPin('0000'), isFalse);
      expect(provider.transactions.length, greaterThan(1200));
      expect(provider.goals, hasLength(4));
      expect(provider.assets, hasLength(5));
      expect(provider.bills, hasLength(5));
      expect(provider.categoryBudgets, hasLength(7));
      expect(provider.currentBalance, repo.balance());
    });

    test('PIN is stored hashed, and a fresh provider can sign in with 1234', () async {
      await FinanceProvider(repo).createDemoAccount();
      final hash = db.raw.select('SELECT pin_hash FROM user_profile').first['pin_hash'];
      expect(hash, isNot(contains('1234')));

      final restarted = FinanceProvider(repo);
      await restarted.init();
      expect(restarted.isLoggedIn, isFalse);
      expect(restarted.hasProfile, isTrue);
      expect(restarted.verifyPin('1234'), isTrue);
      expect(restarted.isLoggedIn, isTrue);
    });

    test('loadDemoData re-seeds only for Demo User', () async {
      final provider = FinanceProvider(repo);
      await provider.init();
      expect(await provider.loadDemoData(), isFalse); // not the demo user

      await provider.createDemoAccount();
      await provider.clearAllData();
      expect(provider.transactions, isEmpty);
      expect(await provider.loadDemoData(), isTrue);
      expect(provider.transactions.length, greaterThan(1200));
      expect(provider.checkPin('1234'), isTrue);
    });
  });
}
