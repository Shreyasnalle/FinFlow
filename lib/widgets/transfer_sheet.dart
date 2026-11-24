import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';

class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  String? _error;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _causeController = TextEditingController();

  void _submit() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (_recipientController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the recipient\'s name.');
      return;
    }
    if (_causeController.text.trim().isEmpty) {
      setState(() => _error = 'Add a cause, for example Rent or Dinner.');
      return;
    }

    final newTransaction = Transaction(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
      category: 'Transfer',
      note: 'To ${_recipientController.text.trim()} · ${_causeController.text.trim()}',
      isIncome: false,
    );

    Provider.of<FinanceProvider>(context, listen: false).addTransaction(newTransaction);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currencySymbol = provider.currencySymbol;

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
            child: Text('Transfer funds', style: GoogleFonts.urbanist(fontSize: 26, fontWeight: FontWeight.w700, color: context.fg)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Amount ($currencySymbol)', prefixText: '$currencySymbol '),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _recipientController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Recipient name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _causeController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Cause', hintText: 'Rent, dinner, gift...'),
          ),
          FormError(_error),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Confirm Transfer'),
            ),
          ),
        ],
      ),
    );
  }
}
