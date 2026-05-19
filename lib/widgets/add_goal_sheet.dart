import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/financial_goal.dart';
import '../providers/finance_provider.dart';


class AddGoalSheet extends StatefulWidget {
  const AddGoalSheet({super.key});

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _savedController = TextEditingController();

  void _submit() {
    final title = _titleController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;
    final saved = double.tryParse(_savedController.text) ?? 0;

    if (title.isEmpty || target <= 0) {
      return;
    }

    final newGoal = FinancialGoal(
      id: const Uuid().v4(),
      title: title,
      targetAmount: target,
      savedAmount: saved,
    );

    Provider.of<FinanceProvider>(context, listen: false).addGoal(newGoal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currencySymbol = provider.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26, 
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(height: 24),
          const Text('New Savings Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Goal Title', hintText: 'Vacation, New Car, etc.'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Target Amount ($currencySymbol)', prefixText: '$currencySymbol '),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _savedController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Already Saved? (Optional)', prefixText: '$currencySymbol '),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Add Goal'),
            ),
          ),
        ],
      ),
    );
  }
}
