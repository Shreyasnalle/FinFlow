import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
        content: Text(
          '$symbol${amount.toInt()} saved toward ${widget.goal.title}!',
          style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w700, color: AppTheme.ink),
        ),
        backgroundColor: AppTheme.lime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;
    final currencySymbol = provider.currencySymbol;
    final percent = widget.goal.targetAmount > 0
        ? (widget.goal.savedAmount / widget.goal.targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

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
          Text('Save to goal',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),

          // Goal summary: blue block with lime chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.blue,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.goal.title,
                        style: GoogleFonts.urbanist(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.lime,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        '${percent.toInt()}%',
                        style: GoogleFonts.urbanist(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatCurrency.format(widget.goal.savedAmount)} / ${formatCurrency.format(widget.goal.targetAmount)}',
                  style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 10,
                    backgroundColor: AppTheme.white.withValues(alpha: 0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.lime),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Remaining: ${formatCurrency.format(_remaining)}',
                  style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.fg),
            decoration: InputDecoration(
              labelText: 'Amount to save ($currencySymbol)',
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
            runSpacing: 8,
            children:
                [500, 1000, 2000, 5000].where((v) => v <= _remaining).map((v) {
              return ActionChip(
                label: Text('$currencySymbol$v'),
                onPressed: () {
                  _amountController.text = v.toString();
                  if (_error != null) setState(() => _error = null);
                },
                backgroundColor: AppTheme.lime,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: GoogleFonts.urbanist(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
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
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  const Expanded(
                    child: Text('Save money', textAlign: TextAlign.center),
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
