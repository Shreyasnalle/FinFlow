import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/financial_goal.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class SaveToGoalSheet extends StatefulWidget {
  final FinancialGoal goal;
  const SaveToGoalSheet({super.key, required this.goal});

  @override
  State<SaveToGoalSheet> createState() => _SaveToGoalSheetState();
}

class _SaveToGoalSheetState extends State<SaveToGoalSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _error;

  double get _remaining => widget.goal.targetAmount - widget.goal.savedAmount;

  void _submit() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final symbol = provider.currencySymbol;
    if (amount > _remaining) {
      setState(() => _error = 'Cannot exceed remaining $symbol${_remaining.toInt()}');
      return;
    }

    provider.saveToGoal(widget.goal.id, amount);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$symbol${amount.toInt()} saved toward ${widget.goal.title}!'),
        backgroundColor: AppTheme.brandDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatCurrency = provider.currencyFormat;
    final currencySymbol = provider.currencySymbol;
    final percent = widget.goal.targetAmount > 0
        ? (widget.goal.savedAmount / widget.goal.targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
          const Text('Save to Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Goal info summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.brandDefault.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.brandDefault.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.goal.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatCurrency.format(widget.goal.savedAmount)} / ${formatCurrency.format(widget.goal.targetAmount)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      '${percent.toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brandDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.black26 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandDefault),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining: ${formatCurrency.format(_remaining)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount to Save ($currencySymbol)',
              prefixText: '$currencySymbol ',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),

          // Quick amount chips
          Wrap(
            spacing: 8,
            children: [500, 1000, 2000, 5000].where((v) => v <= _remaining).map((v) {
              return ActionChip(
                label: Text('$currencySymbol$v'),
                onPressed: () {
                  _amountController.text = v.toString();
                  if (_error != null) setState(() => _error = null);
                },
                backgroundColor: AppTheme.brandDefault.withValues(alpha: 0.12),
                labelStyle: const TextStyle(
                  color: AppTheme.brandDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Save Money'),
            ),
          ),
        ],
      ),
    );
  }
}
