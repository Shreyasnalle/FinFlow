import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/recurring_bill.dart';

class BillBottomSheet extends StatefulWidget {
  final RecurringBill? bill;

  const BillBottomSheet({super.key, this.bill});

  @override
  State<BillBottomSheet> createState() => _BillBottomSheetState();
}

class _BillBottomSheetState extends State<BillBottomSheet> {
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
    if (name.isEmpty || amountRaw.isEmpty || _selectedDate == null) return;

    final amount = double.tryParse(amountRaw);
    if (amount == null) return;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Text(
            widget.bill != null ? 'Update Bill' : 'Schedule Recurring Bill',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
