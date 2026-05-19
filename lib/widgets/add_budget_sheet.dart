import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AddBudgetSheet extends StatefulWidget {
  const AddBudgetSheet({super.key});

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  final _categoryController = TextEditingController();
  final _budgetController = TextEditingController();
  String? _selectedCategory;

  static const List<String> _suggestedCategories = [
    'Food',
    'Groceries',
    'Transport',
    'Rent',
    'Entertainment',
    'Shopping',
    'Health',
    'Education',
    'Dining Out',
    'Utilities',
    'Travel',
    'Subscriptions',
  ];

  @override
  void dispose() {
    _categoryController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submit() {
    final category =
        _selectedCategory ?? _categoryController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim());

    if (category.isEmpty || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid category and budget')),
      );
      return;
    }

    Provider.of<FinanceProvider>(context, listen: false)
        .setCategoryBudget(category, budget);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currencySymbol = provider.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existing = provider.categoryBudgets.keys.toSet();

    // Filter out categories that already have a budget
    final available = _suggestedCategories
        .where((c) => !existing.contains(c))
        .toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Set Category Budget',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track spending against a monthly limit',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          // Suggested category chips
          if (available.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'POPULAR CATEGORIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: available.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = available[i];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor:
                        AppTheme.brandDefault.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.brandDefault
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (v) {
                      setState(() {
                        _selectedCategory = v ? cat : null;
                        if (v) _categoryController.clear();
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Custom category input
          TextField(
            controller: _categoryController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Or type a custom category',
              hintText: 'e.g. Pet Care',
              prefixIcon: const Icon(Icons.category_outlined),
              suffixIcon: _selectedCategory != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _selectedCategory = null),
                    )
                  : null,
            ),
            onChanged: (_) {
              if (_selectedCategory != null) {
                setState(() => _selectedCategory = null);
              }
            },
          ),
          const SizedBox(height: 16),

          // Budget amount
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Monthly Budget ($currencySymbol)',
              prefixText: '$currencySymbol ',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Set Budget',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
