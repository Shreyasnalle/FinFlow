import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/financial_goal.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';

class AddGoalSheet extends StatefulWidget {
  const AddGoalSheet({super.key});

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  String? _error;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _savedController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;
    final saved = double.tryParse(_savedController.text) ?? 0;

    if (title.isEmpty) {
      setState(() => _error = 'Give your goal a name.');
      return;
    }
    if (target <= 0) {
      setState(() => _error = 'Enter a target amount greater than 0.');
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
          Text('New savings goal',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Set a target and fund it bit by bit',
              style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.fgMuted)),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
            decoration: const InputDecoration(
                labelText: 'Goal title', hintText: 'Vacation, New Car, etc.'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
            decoration: InputDecoration(
                labelText: 'Target amount ($currencySymbol)',
                prefixText: '$currencySymbol '),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _savedController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
            decoration: InputDecoration(
                labelText: 'Already saved? (optional)',
                prefixText: '$currencySymbol '),
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
                    child: Text('Add goal', textAlign: TextAlign.center),
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
