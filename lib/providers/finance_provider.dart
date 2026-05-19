import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/financial_goal.dart';
import '../models/recurring_bill.dart';
import '../models/asset.dart';

class FinanceProvider with ChangeNotifier {
  Box? _box;
  List<Transaction> _transactions = [];
  List<FinancialGoal> _goals = [];
  List<RecurringBill> _bills = [];
  List<Asset> _assets = [];

  double _monthlyGoal = 0;

  // Category budgets: { 'Food': 5000.0, 'Transport': 2000.0, ... }
  Map<String, double> _categoryBudgets = {};

  List<Transaction> get transactions => _transactions;
  List<FinancialGoal> get goals => _goals;
  List<RecurringBill> get bills => _bills;
  List<Asset> get assets => _assets;
  Future<void> _seedInitialDataIfEmpty() async {
    // Demo seed removed to avoid false/test data.
    if (_box == null || _box!.isNotEmpty) return;
    // Intentionally not seeding any initial/demo data.
    return;
  }
        id: const Uuid().v4(),
        amount: 4500,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 2),
        category: 'Food',
        note: 'Mess and festival treats',
        isIncome: false,
      ),
      Transaction(
        id: const Uuid().v4(),
        amount: 1400,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 8),
        category: 'Transport',
        note: 'Travel during holidays',
        isIncome: false,
      ),
      Transaction(
        id: const Uuid().v4(),
        amount: 499,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 12),
        category: 'Recurring Bill',
        note: 'Mobile recharge',
        isIncome: false,
      ),
      Transaction(
        id: const Uuid().v4(),
        amount: 799,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 16),
        category: 'Recurring Bill',
        note: 'Internet bill',
        isIncome: false,
      ),
      Transaction(
        id: const Uuid().v4(),
        amount: 3200,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 20),
        category: 'Entertainment',
        note: 'Christmas and New Year shopping',
        isIncome: false,
      ),
      Transaction(
        id: const Uuid().v4(),
        amount: 1800,
        date: DateTime(fourMonthsAgo.year, fourMonthsAgo.month, 25),
        category: 'Groceries',
        note: 'Festival preparations',
        isIncome: false,
      ),
    ];

    final initialGoals = [
      FinancialGoal(
        id: const Uuid().v4(),
        title: 'Emergency Fund',
        targetAmount: 12000,
        savedAmount: 3200,
      ),
      FinancialGoal(
        id: const Uuid().v4(),
        title: 'New Laptop',
        targetAmount: 45000,
        savedAmount: 7000,
      ),
    ];

    final initialBills = [
      RecurringBill(
        id: const Uuid().v4(),
        name: 'Mobile Recharge',
        amount: 499,
        dueDate: DateTime(now.year, now.month, 5),
      ),
      RecurringBill(
        id: const Uuid().v4(),
        name: 'Home Internet',
        amount: 799,
        dueDate: DateTime(now.year, now.month, 20),
      ),
    ];

    final initialAssets = [
      Asset(
        id: const Uuid().v4(),
        name: 'Savings Wallet',
        value: 4200,
      ),
      Asset(
        id: const Uuid().v4(),
        name: 'Gift Cash',
        value: 1500,
      ),
    ];

    final initialBudgets = {
      'Food': 5000.0,
      'Transport': 2000.0,
      'Study': 2000.0,
      'Entertainment': 1200.0,
      'Health': 1200.0,
      'Groceries': 2200.0,
    };

    await _box!.put('userName', userName);
    await _box!.put('userMobile', userMobile);
    await _box!.put('userAge', userAge);
    await _box!.put('userProfession', userProfession);
    await _box!.put('userPin', userPin);
    await _box!.put('transactions', initialTransactions.map((t) => t.toMap()).toList());
    await _box!.put('goals', initialGoals.map((g) => g.toMap()).toList());
    await _box!.put('bills', initialBills.map((b) => b.toMap()).toList());
    await _box!.put('assets', initialAssets.map((a) => a.toMap()).toList());
    await _box!.put('categoryBudgets', initialBudgets);
  }
//demo data  khatam

  void _loadTheme() {
    if (_box == null) return;
    int themeIndex = _box!.get('themeMode', defaultValue: 0);
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  void _loadCurrency() {
    if (_box == null) return;
    _currency = _box!.get('currency', defaultValue: '₹ INR');
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _currency = currency;
    if (_box != null) {
      await _box!.put('currency', currency);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    if (_box != null) {
      await _box!.put('themeMode', mode.index);
    }
    notifyListeners();
  }

  void _loadGoals() {
    if (_box == null) return;
    final List<dynamic> rawList = _box!.get('goals', defaultValue: []);
    _goals = rawList
        .map((e) => FinancialGoal.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  void _loadBills() {
    if (_box == null) return;
    final List<dynamic> rawList = _box!.get('bills', defaultValue: []);
    _bills = rawList
        .map((e) => RecurringBill.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> _processRecurringBills() async {
    if (_bills.isEmpty) return;
    bool needsSave = false;
    final now = DateTime.now();

    for (int i = 0; i < _bills.length; i++) {
      var bill = _bills[i];
      // Keep adding transactions and shifting date until it's no longer past due
      while (bill.dueDate.isBefore(now)) {
        await addTransaction(Transaction(
          id: const Uuid().v4(),
          amount: bill.amount,
          date: bill.dueDate,
          category: 'Recurring Bill',
          note: bill.name,
          isIncome: false,
        ));
        
        int nextMonth = bill.dueDate.month + 1;
        int nextYear = bill.dueDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        
        bill = RecurringBill(
          id: bill.id,
          name: bill.name,
          amount: bill.amount,
          dueDate: DateTime(nextYear, nextMonth, bill.dueDate.day),
        );
        needsSave = true;
      }
      _bills[i] = bill;
    }

    if (needsSave) {
      await _saveBills();
    }
  }

  void _loadAssets() {
    if (_box == null) return;
    final List<dynamic> rawList = _box!.get('assets', defaultValue: []);
    _assets = rawList
        .map((e) => Asset.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  void _loadTransactions() {
    if (_box == null) return;
    final List<dynamic> rawList = _box!.get('transactions', defaultValue: []);
    _transactions = rawList
        .map((e) => Transaction.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    // Sort by date descending
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  void _loadUserProfile() {
    if (_box == null) return;
    _userName = _box!.get('userName', defaultValue: "User");
    _userMobile = _box!.get('userMobile', defaultValue: "");
    _userAge = _box!.get('userAge', defaultValue: "");
    _userProfession = _box!.get('userProfession', defaultValue: "");
    _userPin = _box!.get('userPin', defaultValue: "");
    notifyListeners();
  }

  Future<void> saveUserProfile({
    required String name,
    required String mobile,
    required String age,
    required String profession,
    String? pin,
  }) async {
    _userName = name;
    _userMobile = mobile;
    _userAge = age;
    _userProfession = profession;
    if (pin != null && pin.length == 4) {
      _userPin = pin;
    }

    if (_box != null) {
      await _box!.put('userName', name);
      await _box!.put('userMobile', mobile);
      await _box!.put('userAge', age);
      await _box!.put('userProfession', profession);
      if (pin != null && pin.length == 4) {
        await _box!.put('userPin', pin);
      }
    }
    notifyListeners();
  }

  /// Verify PIN and set logged-in state.
  bool verifyPin(String pin) {
    if (pin == _userPin) {
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

  /// Clear session (in-memory only — profile data stays in Hive).
  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  void setMonthlyGoal(double value) {
    _monthlyGoal = value;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      await _saveTransactions();
    }
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _saveTransactions();
  }

  Future<void> _saveTransactions() async {
    if (_box == null) return;
    final List<Map<String, dynamic>> mapList =
        _transactions.map((t) => t.toMap()).toList();
    await _box!.put('transactions', mapList);
    notifyListeners();
  }

  double get currentBalance {
    double balance = 0;
    for (var t in _transactions) {
      if (t.isIncome) {
        balance += t.amount;
      } else {
        balance -= t.amount;
      }
    }
    return balance;
  }

  double get averageMonthlyNet {
    if (_transactions.isEmpty) return 0.0;

    double totalIncome = 0;
    double totalExpense = 0;
    Set<String> months = {};

    for (var t in _transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
      months.add("${t.date.year}-${t.date.month}");
    }

    int monthCount = months.length;
    if (monthCount == 0) return 0.0;

    return (totalIncome - totalExpense) / monthCount;
  }

  List<List<double>> get projection {
    double current = currentBalance;
    double monthlyNet = averageMonthlyNet;
    List<double> forecast = [];
    List<double> goalTrajectory = [];

    double investmentCorpus = 0;
    for (var t in _transactions) {
      if (t.isInvestment && t.isIncome == false) {
        investmentCorpus += t.amount;
      }
    }

    for (int i = 1; i <= 12; i++) {
      double growth = investmentCorpus * (0.01 * i);
      double totalProjected = current + (monthlyNet * i) + growth;
      forecast.add(totalProjected);
      goalTrajectory.add(current + (_monthlyGoal * i));
    }

    return [forecast, goalTrajectory];
  }

  List<double> getForecastData() {
    double current = currentBalance;
    double monthlyNet = averageMonthlyNet;
    List<double> forecast = [];

    for (int i = 1; i <= 12; i++) {
      forecast.add(current + (monthlyNet * i));
    }

    return forecast;
  }

  Map<String, double> get spendingPerCategory {
    Map<String, double> totals = {};
    for (var t in _transactions) {
      if (!t.isIncome) {
        String catLower = t.category.toLowerCase();
        String actualKey = _categoryBudgets.keys.firstWhere(
          (k) => k.toLowerCase() == catLower, 
          orElse: () => t.category
        );
        totals[actualKey] = (totals[actualKey] ?? 0) + t.amount;
      }
    }
    return totals;
  }

  // ── Category Budgets ──

  void _loadCategoryBudgets() {
    if (_box == null) return;
    final raw = _box!.get('categoryBudgets', defaultValue: {});
    _categoryBudgets = Map<String, double>.from(raw);
    notifyListeners();
  }

  Future<void> _saveCategoryBudgets() async {
    if (_box == null) return;
    await _box!.put('categoryBudgets', Map<String, double>.from(_categoryBudgets));
    notifyListeners();
  }

  Future<void> setCategoryBudget(String category, double budget) async {
    _categoryBudgets[category] = budget;
    await _saveCategoryBudgets();
  }

  Future<void> removeCategoryBudget(String category) async {
    _categoryBudgets.remove(category);
    await _saveCategoryBudgets();
  }

  /// Spending grouped by category for the CURRENT calendar month only.
  Map<String, double> get currentMonthSpendingByCategory {
    final now = DateTime.now();
    Map<String, double> totals = {};
    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == now.year && t.date.month == now.month) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
      }
    }
    return totals;
  }

  /// Total spending for the current calendar month.
  double get totalCurrentMonthSpending {
    final now = DateTime.now();
    double total = 0;
    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == now.year && t.date.month == now.month) {
        total += t.amount;
      }
    }
    return total;
  }

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
    final weekCount = ((lastDay + 6) / 7).ceil();
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

  /// Returns every month for which there is expense data, sorted earliest first.
  List<DateTime> get expenseMonths {
    final months = <DateTime>{};
    for (var t in _transactions) {
      if (!t.isIncome) {
        months.add(DateTime(t.date.year, t.date.month));
      }
    }
    final monthList = months.toList();
    monthList.sort((a, b) => a.compareTo(b));
    return monthList;
  }

  /// Spending grouped by category for the provided month.
  Map<String, double> spendingByCategoryForMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    final totals = <String, double>{};
    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == normalized.year && t.date.month == normalized.month) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
      }
    }
    return totals;
  }

  /// Total expense amount for the provided month.
  double totalExpenseForMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    double total = 0;
    for (var t in _transactions) {
      if (!t.isIncome && t.date.year == normalized.year && t.date.month == normalized.month) {
        total += t.amount;
      }
    }
    return total;
  }

  /// Total income for the current calendar month.
  double get currentMonthIncome {
    final now = DateTime.now();
    double total = 0;
    for (var t in _transactions) {
      if (t.isIncome && t.date.year == now.year && t.date.month == now.month) {
        total += t.amount;
      }
    }
    return total;
  }

  Map<DateTime, int> get heatmapData {
    Map<DateTime, int> data = {};
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
  Future<void> addGoal(FinancialGoal goal) async {
    _goals.add(goal);
    await _saveGoals();
  }

  Future<void> updateGoal(FinancialGoal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      await _saveGoals();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _saveGoals();
  }

  Future<void> _saveGoals() async {
    if (_box == null) return;
    final List<Map<String, dynamic>> mapList =
        _goals.map((g) => g.toMap()).toList();
    await _box!.put('goals', mapList);
    notifyListeners();
  }

  // --- Save Money Toward a Goal ---
  Future<void> saveToGoal(String goalId, double amount) async {
    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1 || amount <= 0) return;
    final goal = _goals[goalIndex];

    // 1. Create expense transaction so it reflects in balance
    final tx = Transaction(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
      category: 'Savings: ${goal.title}',
      note: 'Saved toward ${goal.title}',
      isIncome: false,
    );
    await addTransaction(tx);

    // 2. Update goal's saved amount
    final updated = FinancialGoal(
      id: goal.id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      savedAmount: goal.savedAmount + amount,
    );
    await updateGoal(updated);
  }

  // --- Bills ---
  Future<void> addBill(RecurringBill bill) async {
    _bills.add(bill);
    await _saveBills();
  }

  Future<void> updateBill(RecurringBill bill) async {
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _bills[index] = bill;
      await _saveBills();
    }
  }

  Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    await _saveBills();
  }

  Future<void> _saveBills() async {
    if (_box == null) return;
    final List<Map<String, dynamic>> mapList =
        _bills.map((b) => b.toMap()).toList();
    await _box!.put('bills', mapList);
    notifyListeners();
  }

  // --- Assets ---
  Future<void> addAsset(Asset asset) async {
    _assets.add(asset);
    await _saveAssets();
  }

  Future<void> updateAsset(Asset asset) async {
    final index = _assets.indexWhere((a) => a.id == asset.id);
    if (index != -1) {
      _assets[index] = asset;
      await _saveAssets();
    }
  }

  Future<void> deleteAsset(String id) async {
    _assets.removeWhere((a) => a.id == id);
    await _saveAssets();
  }

  Future<void> _saveAssets() async {
    if (_box == null) return;
    final List<Map<String, dynamic>> mapList =
        _assets.map((a) => a.toMap()).toList();
    await _box!.put('assets', mapList);
    notifyListeners();
  }
}
