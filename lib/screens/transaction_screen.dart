import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_sheet.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatCurrency = provider.currencyFormat;

    void showEditTransaction(Transaction transaction) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionSheet(transaction: transaction),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: provider.transactions.isEmpty
          ? const Center(child: Text("No transactions available.", style: TextStyle(color: AppTheme.textMuted)))
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: provider.transactions.length,
              separatorBuilder: (context, index) => const Divider(color: AppTheme.borderColor),
              itemBuilder: (context, index) {
                final t = provider.transactions[index];
                return Dismissible(
                  key: Key(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Transaction'),
                            content: const Text('Do you want to remove this transaction?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) {
                    provider.deleteTransaction(t.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction deleted')),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.isIncome ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.errorRed.withValues(alpha: 0.1),
                      child: Icon(
                        t.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: t.isIncome ? AppTheme.accent : AppTheme.errorRed,
                      ),
                    ),
                    title: Text(t.category, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat.yMMMd().format(t.date), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        if (t.note.isNotEmpty)
                          Text(t.note, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                    trailing: Text(
                      '${t.isIncome ? '+' : '-'}${formatCurrency.format(t.amount)}',
                      style: TextStyle(
                        color: t.isIncome ? AppTheme.accent : AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => showEditTransaction(t),
                  ),
                );
              },
            ),
    );
  }
}
