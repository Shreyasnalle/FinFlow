import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/tap_scale.dart';

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
      appBar: AppBar(title: const Text('All transactions')),
      body: provider.transactions.isEmpty
          ? Center(
              child: Text('No transactions available.',
                  style: GoogleFonts.urbanist(color: context.fgMuted, fontSize: 15, fontWeight: FontWeight.w500)),
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: provider.transactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final t = provider.transactions[index];
                return Dismissible(
                  key: Key(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete transaction'),
                            content: const Text('Do you want to remove this transaction?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
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
                  child: TapScale(
                    onTap: () => showEditTransaction(t),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.isIncome ? AppTheme.lime : AppTheme.lavender,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              t.isIncome ? Icons.south_west : Icons.north_east,
                              color: AppTheme.ink,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.category,
                                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 15, color: context.fg)),
                                const SizedBox(height: 2),
                                Text(
                                  t.note.isNotEmpty
                                      ? '${DateFormat.yMMMd().format(t.date)} · ${t.note}'
                                      : DateFormat.yMMMd().format(t.date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w500, color: context.fgMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${t.isIncome ? '+' : '-'}${formatCurrency.format(t.amount)}',
                            style: GoogleFonts.urbanist(
                              color: t.isIncome ? context.fg : context.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
