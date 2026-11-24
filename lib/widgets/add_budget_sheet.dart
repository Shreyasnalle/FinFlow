import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';

class AddBudgetSheet extends StatefulWidget {
  const AddBudgetSheet({super.key});

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  String? _error;
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
      setState(() => _error = category.isEmpty ? 'Choose or type a category.' : 'Enter a budget greater than 0.');
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
    final existing = provider.categoryBudgets.keys.toSet();

    final available = _suggestedCategories
        .where((c) => !existing.contains(c))
        .toList();

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: context.fgFaint,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Set category budget',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Track spending against a monthly limit',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.fgMuted,
            ),
          ),
          const SizedBox(height: 24),

          if (available.isNotEmpty) ...[
            Text(
              'POPULAR CATEGORIES',
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.fgMuted,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
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
                    showCheckmark: false,
                    selectedColor: AppTheme.lime,
                    backgroundColor: context.surface,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: GoogleFonts.urbanist(
                      color: isSelected ? AppTheme.ink : context.fg,
                      fontWeight: FontWeight.w700,
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

          TextField(
            controller: _categoryController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
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
          const SizedBox(height: 14),

          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
            decoration: InputDecoration(
              labelText: 'Monthly budget ($currencySymbol)',
              prefixText: '$currencySymbol ',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          FormError(_error),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  const Expanded(
                    child: Text('Set budget', textAlign: TextAlign.center),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.isDark ? AppTheme.ink : AppTheme.lime,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18,
                        color: context.isDark ? AppTheme.lime : AppTheme.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
