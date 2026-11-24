import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/common.dart';

import '../models/asset.dart';
import '../models/financial_goal.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';
import 'app_database.dart';

int toMinor(double amount) => (amount * 100).round();
double fromMinor(int minor) => minor / 100;

class ProfileRow {
  const ProfileRow({
    required this.name,
    required this.mobile,
    required this.age,
    required this.profession,
    required this.themeMode,
    required this.currency,
    required this.aiApiKey,
    required this.hasPin,
  });

  final String name, mobile, age, profession, currency, aiApiKey;
  final int themeMode;
  final bool hasPin;
}

class MonthlySummaryRow {
  const MonthlySummaryRow({
    required this.monthKey,
    required this.income,
    required this.expense,
    required this.investment,
  });

  /// 'YYYY-MM'
  final String monthKey;
  final double income, expense, investment;

  /// Non-income outflow: the app's notion of "spending".
  double get outflow => expense + investment;
  double get net => income - outflow;
  DateTime get month => DateTime(
      int.parse(monthKey.substring(0, 4)), int.parse(monthKey.substring(5, 7)));
}

class CategorySpendRow {
  const CategorySpendRow(this.monthKey, this.category, this.spent);
  final String monthKey, category;
  final double spent;
}

/// All reads and writes go through here. Each public mutation is one atomic
/// transaction (the "stored procedure" layer); the schema's constraints and
/// triggers enforce the invariants underneath, so callers can't bypass them.
class FinanceRepository {
  FinanceRepository(AppDatabase database) : _db = database.raw {
    _db.execute(
        'INSERT OR IGNORE INTO user_profile (id, updated_at) VALUES (1, ?)',
        [_now()]);
  }

  final CommonDatabase _db;
  int _depth = 0;

  static int _now() => DateTime.now().millisecondsSinceEpoch;
  static String _iso(DateTime d) => d.toLocal().toIso8601String();

  T transaction<T>(T Function() body) {
    if (_depth > 0) return body();
    _db.execute('BEGIN IMMEDIATE');
    _depth++;
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      _depth--;
    }
  }

  // ── Profile & preferences ────────────────────────────────────────────────

  ProfileRow loadProfile() {
    final r = _db.select('SELECT name, mobile, age, profession, theme_mode, '
            'currency, ai_api_key, pin_hash FROM user_profile WHERE id = 1')
        .first;
    return ProfileRow(
      name: r['name'] as String,
      mobile: r['mobile'] as String,
      age: r['age'] as String,
      profession: r['profession'] as String,
      themeMode: r['theme_mode'] as int,
      currency: r['currency'] as String,
      aiApiKey: r['ai_api_key'] as String,
      hasPin: (r['pin_hash'] as String).isNotEmpty,
    );
  }

  void saveProfile({
    required String name,
    required String mobile,
    required String age,
    required String profession,
    String? pin,
  }) {
    transaction(() {
      _db.execute(
          'UPDATE user_profile SET name = ?, mobile = ?, age = ?, '
          'profession = ?, updated_at = ? WHERE id = 1',
          [name, mobile, age, profession, _now()]);
      if (pin != null && pin.length == 4) _setPin(pin);
    });
  }

  void _setPin(String pin) {
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    _db.execute(
        'UPDATE user_profile SET pin_hash = ?, pin_salt = ?, updated_at = ? '
        'WHERE id = 1',
        [_hashPin(pin, salt), salt, _now()]);
  }

  /// Iterated SHA-256. A 4-digit PIN is brute-forceable by nature, so this is a
  /// screen lock, not encryption: the database file itself is plain SQLite.
  /// This just avoids storing the PIN in clear.
  static String _hashPin(String pin, String salt) {
    List<int> digest = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool verifyPin(String pin) {
    final r = _db
        .select('SELECT pin_hash, pin_salt FROM user_profile WHERE id = 1')
        .first;
    final stored = r['pin_hash'] as String;
    return stored.isNotEmpty && stored == _hashPin(pin, r['pin_salt'] as String);
  }

  void setThemeMode(int index) => _db.execute(
      'UPDATE user_profile SET theme_mode = ?, updated_at = ? WHERE id = 1',
      [index, _now()]);

  void setCurrency(String currency) => _db.execute(
      'UPDATE user_profile SET currency = ?, updated_at = ? WHERE id = 1',
      [currency, _now()]);

  void setAiApiKey(String key) => _db.execute(
      'UPDATE user_profile SET ai_api_key = ?, updated_at = ? WHERE id = 1',
      [key, _now()]);

  // ── Categories ───────────────────────────────────────────────────────────

  int _categoryId(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Category name cannot be empty');
    _db.execute('INSERT OR IGNORE INTO categories (name, created_at) VALUES (?, ?)',
        [n, _now()]);
    return _db.select('SELECT id FROM categories WHERE name = ?', [n]).first['id']
        as int;
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  static String _kindOf(Transaction t) =>
      t.isIncome ? 'income' : (t.isInvestment ? 'investment' : 'expense');

  /// Newest first, served by idx_txn_occurred.
  List<Transaction> loadTransactions() {
    final rows = _db.select('SELECT t.id, t.amount_minor, t.occurred_at, '
        't.note, t.kind, c.name AS category '
        'FROM transactions t JOIN categories c ON c.id = t.category_id '
        'ORDER BY t.occurred_at DESC, t.id DESC');
    return [
      for (final r in rows)
        Transaction(
          id: r['id'] as String,
          amount: fromMinor(r['amount_minor'] as int),
          date: DateTime.parse(r['occurred_at'] as String),
          category: r['category'] as String,
          note: r['note'] as String,
          isIncome: r['kind'] == 'income',
          isInvestment: r['kind'] == 'investment',
        ),
    ];
  }

  void addTransaction(Transaction t) => transaction(() => _insertTransaction(t));

  void _insertTransaction(
    Transaction t, {
    String source = 'manual',
    String? billId,
    String? goalId,
    bool ignoreDuplicate = false,
  }) {
    _db.execute(
        '${ignoreDuplicate ? 'INSERT OR IGNORE' : 'INSERT'} INTO transactions '
        '(id, amount_minor, occurred_at, category_id, note, kind, source, '
        'bill_id, goal_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          t.id,
          toMinor(t.amount),
          _iso(t.date),
          _categoryId(t.category),
          t.note,
          _kindOf(t),
          source,
          billId,
          goalId,
          _now(),
        ]);
  }

  void updateTransaction(Transaction t) => transaction(() {
        _db.execute(
            'UPDATE transactions SET amount_minor = ?, occurred_at = ?, '
            'category_id = ?, note = ?, kind = ? WHERE id = ?',
            [
              toMinor(t.amount),
              _iso(t.date),
              _categoryId(t.category),
              t.note,
              _kindOf(t),
              t.id,
            ]);
      });

  void deleteTransaction(String id) =>
      _db.execute('DELETE FROM transactions WHERE id = ?', [id]);

  // ── Aggregates (from the trigger-maintained rollup) ──────────────────────

  double balance() =>
      fromMinor(_db.select('SELECT balance_minor FROM v_balance').first['balance_minor']
          as int);

  List<MonthlySummaryRow> loadMonthlySummary() {
    final rows = _db.select(
        'SELECT month_key, income_minor, expense_minor, investment_minor '
        'FROM v_monthly_summary ORDER BY month_key');
    return [
      for (final r in rows)
        MonthlySummaryRow(
          monthKey: r['month_key'] as String,
          income: fromMinor(r['income_minor'] as int),
          expense: fromMinor(r['expense_minor'] as int),
          investment: fromMinor(r['investment_minor'] as int),
        ),
    ];
  }

  List<CategorySpendRow> loadCategorySpend() {
    final rows = _db.select(
        'SELECT month_key, category, spent_minor FROM v_category_spend');
    return [
      for (final r in rows)
        CategorySpendRow(r['month_key'] as String, r['category'] as String,
            fromMinor(r['spent_minor'] as int)),
    ];
  }

  // ── Budgets ──────────────────────────────────────────────────────────────

  Map<String, double> loadBudgets() => {
        for (final r in _db.select('SELECT c.name, b.monthly_limit_minor '
            'FROM budgets b JOIN categories c ON c.id = b.category_id '
            'ORDER BY c.name'))
          r['name'] as String: fromMinor(r['monthly_limit_minor'] as int),
      };

  void setBudget(String category, double limit) => transaction(() {
        _db.execute(
            'INSERT INTO budgets (category_id, monthly_limit_minor, updated_at) '
            'VALUES (?, ?, ?) ON CONFLICT (category_id) DO UPDATE SET '
            'monthly_limit_minor = excluded.monthly_limit_minor, '
            'updated_at = excluded.updated_at',
            [_categoryId(category), toMinor(limit), _now()]);
      });

  void removeBudget(String category) => _db.execute(
      'DELETE FROM budgets WHERE category_id = '
      '(SELECT id FROM categories WHERE name = ?)',
      [category.trim()]);

  // ── Goals ────────────────────────────────────────────────────────────────

  List<FinancialGoal> loadGoals() => [
        for (final r in _db.select(
            'SELECT id, title, target_minor, saved_minor FROM goals '
            'ORDER BY created_at, rowid'))
          FinancialGoal(
            id: r['id'] as String,
            title: r['title'] as String,
            targetAmount: fromMinor(r['target_minor'] as int),
            savedAmount: fromMinor(r['saved_minor'] as int),
          ),
      ];

  void addGoal(FinancialGoal g) => _db.execute(
      'INSERT INTO goals (id, title, target_minor, saved_minor, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [g.id, g.title, toMinor(g.targetAmount), toMinor(g.savedAmount), _now()]);

  void updateGoal(FinancialGoal g) => _db.execute(
      'UPDATE goals SET title = ?, target_minor = ?, saved_minor = ? WHERE id = ?',
      [g.title, toMinor(g.targetAmount), toMinor(g.savedAmount), g.id]);

  void deleteGoal(String id) =>
      _db.execute('DELETE FROM goals WHERE id = ?', [id]);

  /// Procedure: records the saving as an expense linked to the goal. The
  /// goal's saved amount is advanced by trigger trg_txn_ai, in the same
  /// transaction, so the two can never disagree.
  bool saveToGoal(String goalId, double amount, String id, {DateTime? at}) =>
      transaction(() {
        if (amount <= 0) return false;
        final goal = _db.select('SELECT title FROM goals WHERE id = ?', [goalId]);
        if (goal.isEmpty) return false;
        final title = goal.first['title'] as String;
        _insertTransaction(
          Transaction(
            id: id,
            amount: amount,
            date: at ?? DateTime.now(),
            category: 'Savings: $title',
            note: 'Saved toward $title',
            isIncome: false,
          ),
          source: 'goal_save',
          goalId: goalId,
        );
        return true;
      });

  // ── Recurring bills ──────────────────────────────────────────────────────

  List<RecurringBill> loadBills() => [
        for (final r in _db.select(
            'SELECT id, name, amount_minor, due_date FROM recurring_bills '
            'ORDER BY created_at, rowid'))
          RecurringBill(
            id: r['id'] as String,
            name: r['name'] as String,
            amount: fromMinor(r['amount_minor'] as int),
            dueDate: DateTime.parse(r['due_date'] as String),
          ),
      ];

  void addBill(RecurringBill b) => _db.execute(
      'INSERT INTO recurring_bills (id, name, amount_minor, due_date, '
      'anchor_day, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [b.id, b.name, toMinor(b.amount), _iso(b.dueDate), b.dueDate.day, _now()]);

  void updateBill(RecurringBill b) => _db.execute(
      'UPDATE recurring_bills SET name = ?, amount_minor = ?, due_date = ?, '
      'anchor_day = ? WHERE id = ?',
      [b.name, toMinor(b.amount), _iso(b.dueDate), b.dueDate.day, b.id]);

  void deleteBill(String id) =>
      _db.execute('DELETE FROM recurring_bills WHERE id = ?', [id]);

  /// Procedure: charges every bill that is past due (one transaction per
  /// missed month) and rolls its due date forward. All-or-nothing; the unique
  /// index uq_bill_occurrence makes a re-run harmless.
  int processDueBills(DateTime now) => transaction(() {
        final due = _db.select(
            'SELECT id, name, amount_minor, due_date, anchor_day '
            'FROM recurring_bills WHERE due_date < ? ORDER BY due_date',
            [_iso(now)]);
        var created = 0;
        for (final r in due) {
          final billId = r['id'] as String;
          final anchor = r['anchor_day'] as int;
          var dueDate = DateTime.parse(r['due_date'] as String);
          while (dueDate.isBefore(now)) {
            _insertTransaction(
              Transaction(
                id: '$billId@${_iso(dueDate)}',
                amount: fromMinor(r['amount_minor'] as int),
                date: dueDate,
                category: 'Recurring Bill',
                note: r['name'] as String,
                isIncome: false,
              ),
              source: 'bill',
              billId: billId,
              ignoreDuplicate: true,
            );
            created++;
            dueDate = _nextMonth(dueDate, anchor);
          }
          _db.execute('UPDATE recurring_bills SET due_date = ? WHERE id = ?',
              [_iso(dueDate), billId]);
        }
        return created;
      });

  static DateTime _nextMonth(DateTime d, int anchorDay) {
    final y = d.month == 12 ? d.year + 1 : d.year;
    final m = d.month == 12 ? 1 : d.month + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, min(anchorDay, lastDay), d.hour, d.minute, d.second,
        d.millisecond);
  }

  // ── Assets ───────────────────────────────────────────────────────────────

  List<Asset> loadAssets() => [
        for (final r in _db.select(
            'SELECT id, name, value_minor FROM assets ORDER BY updated_at, rowid'))
          Asset(
            id: r['id'] as String,
            name: r['name'] as String,
            value: fromMinor(r['value_minor'] as int),
          ),
      ];

  void addAsset(Asset a) => _db.execute(
      'INSERT INTO assets (id, name, value_minor, updated_at) VALUES (?, ?, ?, ?)',
      [a.id, a.name, toMinor(a.value), _now()]);

  void updateAsset(Asset a) => _db.execute(
      'UPDATE assets SET name = ?, value_minor = ?, updated_at = ? WHERE id = ?',
      [a.name, toMinor(a.value), _now(), a.id]);

  void deleteAsset(String id) =>
      _db.execute('DELETE FROM assets WHERE id = ?', [id]);

  // ── Maintenance ──────────────────────────────────────────────────────────

  /// Procedure: wipes all user data but keeps the profile row (name, PIN,
  /// theme, currency). Child rows go first to respect foreign keys.
  void clearAllData() => transaction(() {
        for (final table in const [
          'transactions',
          'goals',
          'recurring_bills',
          'assets',
          'budgets',
          'categories',
          'monthly_rollup',
          'memory_facts',
          'agent_memory',
          'investor_profile',
          'recommendations',
          'chat_messages',
          'audit_log',
        ]) {
          _db.execute('DELETE FROM $table');
        }
      });
}
