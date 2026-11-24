import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/database/app_database.dart';
import 'package:personal_finance_app/database/finance_repository.dart';
import 'package:personal_finance_app/database/memory_store.dart';
import 'package:personal_finance_app/models/asset.dart';
import 'package:personal_finance_app/models/financial_goal.dart';
import 'package:personal_finance_app/models/recurring_bill.dart';
import 'package:personal_finance_app/models/transaction.dart';
import 'package:sqlite3/common.dart';

Transaction tx(String id, double amount, DateTime date,
        {String category = 'Food', bool income = false, bool invest = false}) =>
    Transaction(
      id: id,
      amount: amount,
      date: date,
      category: category,
      isIncome: income,
      isInvestment: invest,
    );

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = FinanceRepository(db);
  });
  tearDown(() => db.close());

  test('database is migrated to v1', () {
    expect(db.raw.select('PRAGMA user_version').first.values.first, 1);
    expect(db.raw.select('PRAGMA foreign_keys').first.values.first, 1);
  });

  group('transactions + rollup triggers', () {
    test('balance and monthly summary follow insert, update, delete', () {
      repo.addTransaction(tx('a', 1000, DateTime(2026, 3, 5), income: true, category: 'Salary'));
      repo.addTransaction(tx('b', 250.5, DateTime(2026, 3, 6)));
      repo.addTransaction(tx('c', 100, DateTime(2026, 3, 7), invest: true, category: 'SIP'));
      expect(repo.balance(), 649.5);

      var m = repo.loadMonthlySummary().single;
      expect(m.monthKey, '2026-03');
      expect([m.income, m.expense, m.investment], [1000, 250.5, 100]);

      repo.updateTransaction(tx('b', 300, DateTime(2026, 4, 1)));
      expect(repo.balance(), 600);
      expect(repo.loadMonthlySummary().map((r) => r.monthKey), ['2026-03', '2026-04']);

      repo.deleteTransaction('b');
      expect(repo.balance(), 900);
      expect(repo.loadMonthlySummary().map((r) => r.monthKey), ['2026-03']);
      expect(db.raw.select('SELECT * FROM monthly_rollup WHERE txn_count <= 0'), isEmpty);
    });

    test('categories are case-insensitive and spend view groups them', () {
      repo.addTransaction(tx('a', 10, DateTime(2026, 3, 1), category: 'Food'));
      repo.addTransaction(tx('b', 5, DateTime(2026, 3, 2), category: 'food'));
      final spend = repo.loadCategorySpend().single;
      expect(spend.category, 'Food');
      expect(spend.spent, 15);
    });

    test('list is newest first', () {
      repo.addTransaction(tx('old', 1, DateTime(2026, 1, 1)));
      repo.addTransaction(tx('new', 1, DateTime(2026, 5, 1)));
      expect(repo.loadTransactions().map((t) => t.id), ['new', 'old']);
    });

    test('constraints reject bad data', () {
      expect(() => repo.addTransaction(tx('z', 0, DateTime(2026, 1, 1))),
          throwsA(isA<SqliteException>()));
      expect(() => repo.addTransaction(tx('z', 5, DateTime(2026, 1, 1), category: '  ')),
          throwsArgumentError);
      expect(
          () => db.raw.execute(
              "INSERT INTO transactions (id, amount_minor, occurred_at, category_id, kind, source, goal_id, created_at) "
              "VALUES ('x', 100, '2026-01-01T00:00:00', 1, 'expense', 'manual', 'nope', 0)"),
          throwsA(isA<SqliteException>()));
    });

    test('a failed procedure rolls back completely', () {
      expect(
          () => repo.transaction(() {
                repo.addTransaction(tx('ok', 10, DateTime(2026, 1, 1)));
                repo.addTransaction(tx('bad', -1, DateTime(2026, 1, 1)));
              }),
          throwsA(isA<SqliteException>()));
      expect(repo.loadTransactions(), isEmpty);
      expect(repo.balance(), 0);
    });

    test('a category in use cannot be deleted', () {
      repo.addTransaction(tx('a', 10, DateTime(2026, 1, 1)));
      expect(() => db.raw.execute('DELETE FROM categories'),
          throwsA(isA<SqliteException>()));
    });
  });

  group('goals', () {
    test('saveToGoal links the expense, advances the goal and completes it', () {
      repo.addGoal(FinancialGoal(id: 'g', title: 'Bike', targetAmount: 100));
      expect(repo.saveToGoal('g', 60, 't1'), isTrue);
      expect(repo.loadGoals().single.savedAmount, 60);
      expect(repo.balance(), -60);

      expect(repo.saveToGoal('g', 40, 't2'), isTrue);
      expect(db.raw.select("SELECT status FROM goals WHERE id = 'g'").first['status'],
          'completed');

      // Deleting the saving reverses progress and reopens the goal.
      repo.deleteTransaction('t2');
      expect(repo.loadGoals().single.savedAmount, 60);
      expect(db.raw.select("SELECT status FROM goals WHERE id = 'g'").first['status'],
          'active');
    });

    test('saveToGoal ignores missing goals and non-positive amounts', () {
      expect(repo.saveToGoal('nope', 10, 't'), isFalse);
      repo.addGoal(FinancialGoal(id: 'g', title: 'X', targetAmount: 10));
      expect(repo.saveToGoal('g', 0, 't'), isFalse);
    });

    test('deleting a goal keeps its transactions', () {
      repo.addGoal(FinancialGoal(id: 'g', title: 'X', targetAmount: 100));
      repo.saveToGoal('g', 10, 't');
      repo.deleteGoal('g');
      expect(repo.loadTransactions(), hasLength(1));
    });

    test('goal_save source requires a goal', () {
      db.raw.execute("INSERT INTO categories (name, created_at) VALUES ('c', 0)");
      expect(
          () => db.raw.execute(
              "INSERT INTO transactions (id, amount_minor, occurred_at, category_id, kind, source, created_at) "
              "VALUES ('y', 100, '2026-01-01T00:00:00', 1, 'expense', 'goal_save', 0)"),
          throwsA(isA<SqliteException>()));
    });
  });

  group('recurring bills', () {
    test('charges every missed month and rolls the due date forward', () {
      repo.addBill(RecurringBill(
          id: 'b', name: 'Rent', amount: 500, dueDate: DateTime(2026, 1, 31)));
      final created = repo.processDueBills(DateTime(2026, 4, 15));
      expect(created, 3); // Jan 31, Feb 28, Mar 31
      expect(repo.balance(), -1500);
      expect(repo.loadBills().single.dueDate, DateTime(2026, 4, 30));
    });

    test('is idempotent', () {
      repo.addBill(RecurringBill(
          id: 'b', name: 'Rent', amount: 500, dueDate: DateTime(2026, 1, 10)));
      repo.processDueBills(DateTime(2026, 3, 1));
      final before = repo.balance();
      expect(repo.processDueBills(DateTime(2026, 3, 1)), 0);
      expect(repo.balance(), before);
    });

    test('deleting a bill keeps the charges it already made', () {
      repo.addBill(RecurringBill(
          id: 'b', name: 'Rent', amount: 500, dueDate: DateTime(2026, 1, 10)));
      repo.processDueBills(DateTime(2026, 1, 20));
      repo.deleteBill('b');
      expect(repo.loadTransactions(), hasLength(1));
    });
  });

  test('asset value changes are recorded in history', () {
    repo.addAsset(Asset(id: 'a', name: 'Gold', value: 1000));
    repo.updateAsset(Asset(id: 'a', name: 'Gold', value: 1200));
    repo.updateAsset(Asset(id: 'a', name: 'Gold renamed', value: 1200));
    final h = db.raw.select(
        'SELECT value_minor FROM asset_history ORDER BY id');
    expect(h.map((r) => r['value_minor']), [100000, 120000]);
    repo.deleteAsset('a');
    expect(db.raw.select('SELECT * FROM asset_history'), isEmpty);
  });

  test('net worth view adds cash and assets', () {
    repo.addTransaction(tx('i', 500, DateTime(2026, 1, 1), income: true, category: 'Pay'));
    repo.addAsset(Asset(id: 'a', name: 'Gold', value: 250));
    final r = db.raw.select('SELECT * FROM v_net_worth').first;
    expect(r['net_worth_minor'], 75000);
  });

  test('budgets: upsert, status view, remove', () {
    repo.setBudget('Food', 100);
    repo.setBudget('food', 150);
    expect(repo.loadBudgets(), {'Food': 150});
    repo.addTransaction(tx('a', 200, DateTime(2026, 3, 1)));
    final s = db.raw.select('SELECT * FROM v_budget_status').first;
    expect(s['over_minor'], 5000);
    repo.removeBudget('Food');
    expect(repo.loadBudgets(), isEmpty);
    expect(() => repo.setBudget('Food', 0), throwsA(isA<SqliteException>()));
  });

  test('audit log captures changes and is pruned', () {
    repo.addTransaction(tx('a', 10, DateTime(2026, 1, 1)));
    repo.deleteTransaction('a');
    final actions = db.raw
        .select("SELECT action FROM audit_log WHERE table_name = 'transactions' ORDER BY id")
        .map((r) => r['action']);
    expect(actions, ['INSERT', 'DELETE']);

    for (var i = 0; i < 5100; i++) {
      db.raw.execute(
          "INSERT INTO audit_log (table_name, row_id, action) VALUES ('t', '$i', 'INSERT')");
    }
    expect(db.raw.select('SELECT count(*) AS n FROM audit_log').first['n'], 5000);
  });

  group('profile', () {
    test('PIN is stored hashed and verifies', () {
      expect(repo.loadProfile().hasPin, isFalse);
      repo.saveProfile(
          name: 'Asha', mobile: '1', age: '30', profession: 'Dev', pin: '1234');
      expect(repo.loadProfile().hasPin, isTrue);
      expect(repo.verifyPin('1234'), isTrue);
      expect(repo.verifyPin('4321'), isFalse);
      final row = db.raw.select('SELECT pin_hash FROM user_profile').first;
      expect(row['pin_hash'], isNot(contains('1234')));

      // Saving without a pin keeps the existing one.
      repo.saveProfile(name: 'Asha2', mobile: '1', age: '30', profession: 'Dev');
      expect(repo.verifyPin('1234'), isTrue);
    });

    test('profile is a single row', () {
      expect(() => db.raw.execute('INSERT INTO user_profile (id, updated_at) VALUES (2, 0)'),
          throwsA(isA<SqliteException>()));
    });
  });

  test('clearAllData wipes everything but the profile', () {
    repo.saveProfile(name: 'A', mobile: '', age: '', profession: '', pin: '1111');
    repo.addTransaction(tx('a', 10, DateTime(2026, 1, 1)));
    repo.addGoal(FinancialGoal(id: 'g', title: 'X', targetAmount: 10));
    repo.saveToGoal('g', 5, 't');
    repo.setBudget('Food', 10);
    repo.addAsset(Asset(id: 'x', name: 'Gold', value: 1));
    repo.addBill(RecurringBill(id: 'b', name: 'R', amount: 1, dueDate: DateTime(2030, 1, 1)));
    MemoryStore(db).write('hello');
    repo.clearAllData();
    expect(repo.loadTransactions(), isEmpty);
    expect(repo.loadGoals(), isEmpty);
    expect(repo.loadAssets(), isEmpty);
    expect(repo.loadBills(), isEmpty);
    expect(repo.loadBudgets(), isEmpty);
    expect(repo.balance(), 0);
    expect(MemoryStore(db).read(), '');
    expect(repo.verifyPin('1111'), isTrue);
  });

  group('agent memory', () {
    test('round-trips compressed, bumps version, detects tampering', () {
      final memory = MemoryStore(db);
      expect(memory.read(), '');
      final text = '# Memory\n${'User prefers index funds. ' * 200}';
      memory.write(text);
      expect(memory.read(), text);
      expect(memory.version, 1);

      final stored = db.raw.select('SELECT length(content) AS c, raw_bytes FROM agent_memory').first;
      expect(stored['c'] as int, lessThan(stored['raw_bytes'] as int));

      memory.write('$text more');
      expect(memory.version, 2);

      db.raw.execute("UPDATE agent_memory SET sha256 = 'deadbeef'");
      expect(memory.read(), '');
    });

    test('facts upsert and delete', () {
      final memory = MemoryStore(db);
      memory.upsertFact('risk', 'moderate', confidence: 0.8);
      memory.upsertFact('risk', 'aggressive');
      expect(memory.facts(), {'risk': 'aggressive'});
      memory.deleteFact('risk');
      expect(memory.facts(), isEmpty);
    });
  });
}
