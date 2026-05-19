import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AddTransactionSheet extends StatefulWidget {
  final Transaction? transaction;
  const AddTransactionSheet({super.key, this.transaction});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  bool _isIncome = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final transaction = widget.transaction!;
      _isIncome = transaction.isIncome;
      _amountController.text = transaction.amount.toStringAsFixed(0);
      _categoryController.text = transaction.category;
      _noteController.text = transaction.note;
    }
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _categoryController.text.isEmpty) {
      return;
    }

    final tx = Transaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      amount: amount,
      date: widget.transaction?.date ?? DateTime.now(),
      category: _capitalizeWords(_categoryController.text.trim()),
      note: _noteController.text.trim(),
      isIncome: _isIncome,
    );

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (widget.transaction == null) {
      provider.addTransaction(tx);
    } else {
      provider.updateTransaction(tx);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = provider.currencySymbol;
    final isEditing = widget.transaction != null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Text('New Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Expense'),
                  selected: !_isIncome,
                  onSelected: (val) => setState(() => _isIncome = !val),
                  selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: !_isIncome ? Colors.redAccent : Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Income'),
                  selected: _isIncome,
                  onSelected: (val) => setState(() => _isIncome = val),
                  selectedColor: AppTheme.brandDark.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _isIncome ? AppTheme.brandDark : Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Amount ($currencySymbol)', prefixText: '$currencySymbol '),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Category', hintText: 'Food, Rent, Salary...'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (Optional)'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Update Transaction' : 'Add Transaction'),
            ),
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                ),
                onPressed: () {
                  provider.deleteTransaction(widget.transaction!.id);
                  Navigator.pop(context);
                },
                child: const Text('Delete Transaction'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
