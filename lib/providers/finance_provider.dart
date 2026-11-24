import '../database/demo_seed.dart';
import '../services/forecast_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../database/finance_repository.dart';
import '../models/asset.dart';
import '../models/financial_goal.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';

class FinanceProvider with ChangeNotifier {
  FinanceProvider(this._repo);

  final FinanceRepository _repo;

  List<Transaction> _transactions = [];
  List<FinancialGoal> _goals = [];
  List<RecurringBill> _bills = [];
  List<Asset> _assets = [];

  // Aggregates served by the database's trigger-maintained rollup.
  double _balance = 0;
  List<MonthlySummaryRow> _monthly = [];
  List<CategorySpendRow> _categorySpend = [];

  double _monthlyGoal = 0;

  // Category budgets: { 'Food': 5000.0, 'Transport': 2000.0, ... }
  Map<String, double> _categoryBudgets = {};

  // Session / profile / preferences
  bool _isLoggedIn = false;
  bool _hasPin = false;
  ThemeMode _themeMode = ThemeMode.light;
  String _currency = '₹ INR';
  String _userName = 'User';
  String _userMobile = '';
  String _userAge = '';
  String _userProfession = '';
  String _aiApiKey = '';

  String get aiApiKey => _aiApiKey;

  // Expected yearly return (0.08 = 8%) shared by Forecast and Goals pages.
  // Kept for the session only.
  double _expectedReturn = 0.08;
  double get expectedReturn => _expectedReturn;
  void setExpectedReturn(double value) {
    _expectedReturn = value.clamp(0.0, 0.30);
    notifyListeners();
  }

  /// Realistic monthly averages from the last few full months.
  MonthlyStats get monthlyStats => ForecastService.analyze(_transactions);

  Future<void> setAiApiKey(String key) async {
    _aiApiKey = key.trim();
    _repo.setAiApiKey(_aiApiKey);
    notifyListeners();
  }

  List<Transaction> get transactions => _transactions;
  List<FinancialGoal> get goals => _goals;
  List<RecurringBill> get bills => _bills;
  List<Asset> get assets => _assets;
  Map<String, double> get categoryBudgets => _categoryBudgets;
  double get monthlyGoal => _monthlyGoal;

  bool get isLoggedIn => _isLoggedIn;
  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;
  String get userName => _userName;
  String get userMobile => _userMobile;
  String get userAge => _userAge;
  String get userProfession => _userProfession;

  /// A profile exists once the user has signed up and set a PIN.
  bool get hasProfile => _hasPin;

  /// Currency symbol taken from the stored "₹ INR" style label.
  String get currencySymbol {
    final parts = _currency.split(' ');
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : '₹';
  }

  /// INR uses lakh/crore grouping (1,40,200.00); other currencies keep 140,200.00.
  NumberFormat get currencyFormat => NumberFormat.currency(
      locale: _currency.contains('INR') ? 'en_IN' : null, symbol: currencySymbol, decimalDigits: 2);

  /// Loads everything from the encrypted database, first charging any bills
  /// that have come due since the app last ran.
  Future<void> init() async {
    _repo.processDueBills(DateTime.now());
    _loadProfile();
    _loadTransactions();
    _loadGoals();
    _loadBills();
    _loadAssets();
    _loadCategoryBudgets();
    notifyListeners();
  }

  static String _monthKey(DateTime m) =>
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

  MonthlySummaryRow? _summaryFor(DateTime month) {
    final key = _monthKey(month);
    for (final row in _monthly) {
      if (row.monthKey == key) return row;
    }
    return null;
  }

  // ── Profile & preferences ──

  void _loadProfile() {
    final p = _repo.loadProfile();
    _userName = p.name;
    _userMobile = p.mobile;
    _userAge = p.age;
    _userProfession = p.profession;
    _aiApiKey = p.aiApiKey;
    _currency = p.currency;
    _themeMode = ThemeMode.values[p.themeMode];
    _hasPin = p.hasPin;
  }

  Future<void> setCurrency(String currency) async {
    _currency = currency;
    _repo.setCurrency(currency);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _repo.setThemeMode(mode.index);
    notifyListeners();
  }

  Future<void> saveUserProfile({
    required String name,
    required String mobile,
    required String age,
    required String profession,
    String? pin,
  }) async {
    _repo.saveProfile(
        name: name, mobile: mobile, age: age, profession: profession, pin: pin);
    _loadProfile();
    notifyListeners();
  }

  /// Checks a PIN without changing session state.
  bool checkPin(String pin) => _repo.verifyPin(pin);

  /// Verify PIN and set logged-in state.
  bool verifyPin(String pin) {
    if (_repo.verifyPin(pin)) {
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Mark user as logged in (after sign-up or PIN verification).
  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  /// Clear session (in-memory only: data stays in the database).
  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  void setMonthlyGoal(double value) {
    _monthlyGoal = value;
    notifyListeners();
  }

  // ── Transactions ──

  void _loadTransactions() {
    _transactions = _repo.loadTransactions();
    _balance = _repo.balance();
    _monthly = _repo.loadMonthlySummary();
    _categorySpend = _repo.loadCategorySpend();
  }

  Future<void> addTransaction(Transaction transaction) async {
    _repo.addTransaction(transaction);
    _loadTransactions();
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    _repo.updateTransaction(transaction);
    _loadTransactions();
    _loadGoals();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    _repo.deleteTransaction(id);
    _loadTransactions();
    _loadGoals();
    notifyListeners();
  }

  double get currentBalance => _balance;

  double get averageMonthlyNet {
    if (_monthly.isEmpty) return 0.0;
    final total = _monthly.fold<double>(0, (sum, m) => sum + m.net);
    return total / _monthly.length;
  }

  List<List<double>> get projection {
    final current = currentBalance;
    final monthlyNet = averageMonthlyNet;
    final forecast = <double>[];
    final goalTrajectory = <double>[];

    final investmentCorpus =
        _monthly.fold<double>(0, (sum, m) => sum + m.investment);

    for (int i = 1; i <= 12; i++) {
      final growth = investmentCorpus * (0.01 * i);
      forecast.add(current + (monthlyNet * i) + growth);
      goalTrajectory.add(current + (_monthlyGoal * i));
    }

    return [forecast, goalTrajectory];
  }

  List<double> getForecastData() {
    final current = currentBalance;
    final monthlyNet = averageMonthlyNet;
    return [for (int i = 1; i <= 12; i++) current + (monthlyNet * i)];
  }

  Map<String, double> get spendingPerCategory {
    final totals = <String, double>{};
    for (final row in _categorySpend) {
      totals[row.category] = (totals[row.category] ?? 0) + row.spent;
    }
    return totals;
  }

  // ── Category Budgets ──

  void _loadCategoryBudgets() {
    _categoryBudgets = _repo.loadBudgets();
  }

  Future<void> setCategoryBudget(String category, double budget) async {
    if (budget <= 0) return;
    _repo.setBudget(category, budget);
    _loadCategoryBudgets();
    notifyListeners();
  }

  Future<void> removeCategoryBudget(String category) async {
    _repo.removeBudget(category);
    _loadCategoryBudgets();
    notifyListeners();
  }

  /// Spending grouped by category for the CURRENT calendar month only.
  Map<String, double> get currentMonthSpendingByCategory =>
      spendingByCategoryForMonth(DateTime.now());

  /// Total spending for the current calendar month.
  double get totalCurrentMonthSpending => totalExpenseForMonth(DateTime.now());

  /// Returns any budget overages for the selected month.
  Map<String, double> budgetVarianceForMonth(DateTime month) {
    final spent = spendingByCategoryForMonth(month);
    final overages = <String, double>{};

    for (final entry in spent.entries) {
      final budget = _categoryBudgets[entry.key];
      if (budget != null && entry.value > budget) {
        overages[entry.key] = entry.value - budget;
      }
    }

    return overages;
  }

  /// Weekly spending totals for a selected month.
  List<Map<String, dynamic>> weeklySpendingForMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = (lastDay / 7).ceil();
    final totals = List<double>.filled(weekCount, 0.0);

    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == month.year && t.date.month == month.month) {
        final index = ((t.date.day - 1) / 7).floor();
        totals[index] += t.amount;
      }
    }

    return List.generate(weekCount, (index) {
      return {
        'label': 'W${index + 1}',
        'amount': totals[index],
      };
    });
  }

  /// Running total of expense for each day of the selected month.
  List<Map<String, dynamic>> runningExpenseForMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final dailyTotals = List<double>.filled(lastDay, 0.0);

    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == month.year && t.date.month == month.month) {
        dailyTotals[t.date.day - 1] += t.amount;
      }
    }

    double cumulative = 0;
    return List.generate(lastDay, (index) {
      cumulative += dailyTotals[index];
      return {
        'day': index + 1,
        'amount': cumulative,
      };
    });
  }

  /// Every month that has expense data, earliest first.
  List<DateTime> get expenseMonths => [
        for (final m in _monthly)
          if (m.outflow > 0) m.month,
      ];

  /// Spending grouped by category for the provided month.
  Map<String, double> spendingByCategoryForMonth(DateTime month) {
    final key = _monthKey(month);
    return {
      for (final row in _categorySpend)
        if (row.monthKey == key) row.category: row.spent,
    };
  }

  /// Total expense amount for the provided month.
  double totalExpenseForMonth(DateTime month) =>
      _summaryFor(month)?.outflow ?? 0;

  /// Total income for the current calendar month.
  double get currentMonthIncome => _summaryFor(DateTime.now())?.income ?? 0;

  Map<DateTime, int> get heatmapData {
    final data = <DateTime, int>{};
    for (var t in _transactions) {
      if (!t.isIncome) {
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        data[date] = (data[date] ?? 0) + t.amount.toInt();
      }
    }
    return data;
  }

  bool get isProjectedDebt {
    final proj = projection;
    if (proj.isEmpty || proj[0].isEmpty) return false;
    return proj[0].any((balance) => balance < 0);
  }

  // --- Goals ---

  void _loadGoals() {
    _goals = _repo.loadGoals();
  }

  Future<void> addGoal(FinancialGoal goal) async {
    _repo.addGoal(FinancialGoal(
      id: goal.id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      savedAmount: goal.savedAmount < 0 ? 0 : goal.savedAmount,
    ));
    _loadGoals();
    notifyListeners();
  }

  Future<void> updateGoal(FinancialGoal goal) async {
    _repo.updateGoal(goal);
    _loadGoals();
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    _repo.deleteGoal(id);
    _loadGoals();
    notifyListeners();
  }

  /// Saves money toward a goal: one atomic database procedure that records the
  /// expense and advances the goal's saved amount together.
  Future<void> saveToGoal(String goalId, double amount) async {
    if (!_repo.saveToGoal(goalId, amount, const Uuid().v4())) return;
    _loadTransactions();
    _loadGoals();
    notifyListeners();
  }

  // --- Bills ---

  void _loadBills() {
    _bills = _repo.loadBills();
  }

  Future<void> addBill(RecurringBill bill) async {
    if (bill.amount <= 0) return;
    _repo.addBill(bill);
    _loadBills();
    notifyListeners();
  }

  Future<void> updateBill(RecurringBill bill) async {
    if (bill.amount <= 0) return;
    _repo.updateBill(bill);
    _loadBills();
    notifyListeners();
  }

  Future<void> deleteBill(String id) async {
    _repo.deleteBill(id);
    _loadBills();
    notifyListeners();
  }

  // --- Assets ---

  void _loadAssets() {
    _assets = _repo.loadAssets();
  }

  Future<void> addAsset(Asset asset) async {
    _repo.addAsset(asset);
    _loadAssets();
    notifyListeners();
  }

  Future<void> updateAsset(Asset asset) async {
    _repo.updateAsset(asset);
    _loadAssets();
    notifyListeners();
  }

  Future<void> deleteAsset(String id) async {
    _repo.deleteAsset(id);
    _loadAssets();
    notifyListeners();
  }

  // --- Maintenance ---

  /// Deletes all transactions, goals, bills, assets and budgets. The profile stays.
  Future<void> clearAllData() async {
    _repo.clearAllData();
    _monthlyGoal = 0;
    _loadTransactions();
    _loadGoals();
    _loadBills();
    _loadAssets();
    _loadCategoryBudgets();
    notifyListeners();
  }

  void _reloadData() {
    _loadTransactions();
    _loadGoals();
    _loadBills();
    _loadAssets();
    _loadCategoryBudgets();
  }

  /// Demo builds only ([DemoSeed.enabled]). Creates the "Demo User" profile
  /// (PIN 1234) with three years of generated history, and signs it in.
  Future<bool> createDemoAccount() async {
    if (!DemoSeed.enabled) return false;
    _repo.transaction(() {
      _repo.clearAllData();
      _repo.saveProfile(
        name: DemoSeed.userName,
        mobile: DemoSeed.mobile,
        age: DemoSeed.age,
        profession: DemoSeed.profession,
        pin: DemoSeed.pin,
      );
      DemoSeed.apply(_repo, DateTime.now());
    });
    _loadProfile();
    _monthlyGoal = 20000;
    _isLoggedIn = true;
    _reloadData();
    notifyListeners();
    return true;
  }

  /// Demo builds only, and only for the "Demo User" account: regenerates the
  /// demo history ending today (e.g. after Clear All Data, or days later).
  Future<bool> loadDemoData() async {
    if (!DemoSeed.enabled || _userName != DemoSeed.userName) return false;
    _repo.transaction(() {
      _repo.clearAllData();
      DemoSeed.apply(_repo, DateTime.now());
    });
    _reloadData();
    notifyListeners();
    return true;
  }
}
