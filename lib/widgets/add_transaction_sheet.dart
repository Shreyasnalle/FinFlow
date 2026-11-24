import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_calendar.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

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
  late DateTime _date;
  String? _error;

  static const _expenseCategories = [
    'Food', 'Groceries', 'Dining', 'Rent', 'Utilities', 'Transport', 'Fuel', 'Shopping',
    'Entertainment', 'Health', 'Education', 'Travel', 'Insurance', 'Subscriptions', 'Other',
  ];
  static const _incomeCategories = [
    'Salary', 'Freelance', 'Business', 'Interest', 'Dividends', 'Rental income', 'Gift', 'Refund', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _date = widget.transaction?.date ?? DateTime.now();
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
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (_categoryController.text.trim().isEmpty) {
      setState(() => _error = 'Add a category, for example Food or Salary.');
      return;
    }

    final tx = Transaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      amount: amount,
      date: _date,
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

  Future<void> _pickDate() async {
    final today = AppCalendar().today;
    final last = today.isBefore(DateTime(_date.year, _date.month, _date.day)) ? DateTime(_date.year, _date.month, _date.day) : today;
    final first = DateTime(today.year - 10).isAfter(_date) ? DateTime(_date.year) : DateTime(today.year - 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(last) ? last : _date,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    // Keep the time of day; only the calendar date changes.
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  Widget _dateField() {
    final isToday = AppCalendar.sameDay(_date, AppCalendar().now);
    return TapScale(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 20, color: context.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${DateFormat('EEE, d MMM yyyy').format(_date)}${isToday ? '  ·  Today' : ''}',
                style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: context.fg),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: context.fgMuted),
          ],
        ),
      ),
    );
  }

  Widget _typePill(String label, bool selected, VoidCallback onTap) {
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime : context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(label,
            style: GoogleFonts.urbanist(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppTheme.ink : context.fgMuted,
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currencySymbol = provider.currencySymbol;
    final isEditing = widget.transaction != null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: AppTheme.lavender, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(isEditing ? 'Edit transaction' : 'New transaction',
                style: GoogleFonts.urbanist(fontSize: 26, fontWeight: FontWeight.w700, color: context.fg)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _typePill('Expense', !_isIncome, () => setState(() => _isIncome = false))),
              const SizedBox(width: 10),
              Expanded(child: _typePill('Income', _isIncome, () => setState(() => _isIncome = true))),
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
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category',
              hintText: 'Pick one or type your own',
              suffixIcon: PopupMenuButton<String>(
                tooltip: 'Choose a category',
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.fgMuted),
                color: context.bg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                constraints: const BoxConstraints(maxHeight: 360),
                onSelected: (c) => setState(() {
                  _categoryController.text = c;
                  _error = null;
                }),
                itemBuilder: (_) => [
                  for (final c in (_isIncome ? _incomeCategories : _expenseCategories))
                    PopupMenuItem<String>(
                      value: c,
                      child: Text(c, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: context.fg)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _dateField(),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (Optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700, color: context.accent)),
            ),
          ],
          const SizedBox(height: 24),
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
                  foregroundColor: context.accent,
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
