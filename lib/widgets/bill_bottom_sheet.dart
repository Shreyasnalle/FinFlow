import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';
import '../models/recurring_bill.dart';

class BillBottomSheet extends StatefulWidget {
  final RecurringBill? bill;

  const BillBottomSheet({super.key, this.bill});

  @override
  State<BillBottomSheet> createState() => _BillBottomSheetState();
}

class _BillBottomSheetState extends State<BillBottomSheet> {
  String? _error;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _nameController.text = widget.bill!.name;
      _amountController.text = widget.bill!.amount.toString();
      _selectedDate = widget.bill!.dueDate;
    } else {
      _selectedDate = DateTime.now(); // default to today
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amountRaw = _amountController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for the bill.');
      return;
    }
    final amount = double.tryParse(amountRaw);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the bill amount as a number greater than 0.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _error = 'Pick the due date.');
      return;
    }

    final provider = Provider.of<FinanceProvider>(context, listen: false);

    if (widget.bill != null) {
      provider.updateBill(RecurringBill(
        id: widget.bill!.id,
        name: name,
        amount: amount,
        dueDate: _selectedDate!,
      ));
    } else {
      provider.addBill(RecurringBill(
        id: const Uuid().v4(),
        name: name,
        amount: amount,
        dueDate: _selectedDate!,
      ));
    }

    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
            child: Text(widget.bill != null ? 'Update bill' : 'Schedule recurring bill', style: GoogleFonts.urbanist(fontSize: 26, fontWeight: FontWeight.w700, color: context.fg)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Bill Name',
              hintText: 'e.g., Netflix, Rent, Phone Bill',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Bill Amount',
              prefixText: '${Provider.of<FinanceProvider>(context).currencySymbol} ',
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next Due Date'),
            subtitle: Text(_selectedDate != null
                ? DateFormat('MMMM d, yyyy').format(_selectedDate!)
                : 'Not Selected'),
            trailing: TextButton(
              onPressed: _pickDate,
              child: const Text('PICK DATE'),
            ),
          ),
          FormError(_error),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: Text(widget.bill != null ? 'Save Changes' : 'Schedule Bill'),
            ),
          ),
        ],
      ),
    );
  }
}
