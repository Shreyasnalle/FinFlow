import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bill_bottom_sheet.dart';

class RecurringBillsScreen extends StatelessWidget {
  const RecurringBillsScreen({super.key});

  void _showBillSheet(BuildContext context, {var bill}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BillBottomSheet(bill: bill),
    );
  }

  void _confirmDelete(BuildContext context, String billId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bill'),
        content: const Text('Are you sure you want to delete this recurring bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<FinanceProvider>(context, listen: false).deleteBill(billId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currency = provider.currencyFormat;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring bills')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBillSheet(context),
        child: const Icon(Icons.add),
      ),
      body: provider.bills.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: context.soft, shape: BoxShape.circle),
                    child: Icon(Icons.receipt_long_outlined, size: 36, color: context.onSoft),
                  ),
                  const SizedBox(height: 16),
                  Text('No recurring bills scheduled',
                      style: GoogleFonts.urbanist(fontSize: 17, fontWeight: FontWeight.w600, color: context.fg)),
                  const SizedBox(height: 6),
                  Text('Automate your fixed bills here',
                      style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: context.fgMuted)),
                ],
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: provider.bills.length,
              itemBuilder: (context, index) {
                final bill = provider.bills[index];

                final difference = bill.dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
                final urgent = difference <= 3;
                String statusText = 'Due in $difference days';
                if (difference < 0) {
                  statusText = 'Overdue';
                } else if (difference == 0) {
                  statusText = 'Due today';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: urgent ? AppTheme.blue : AppTheme.lavender,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.payment, size: 20, color: urgent ? AppTheme.white : AppTheme.ink),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bill.name,
                                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16, color: context.fg)),
                                  const SizedBox(height: 2),
                                  Text(currency.format(bill.amount),
                                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 14, color: context.accent)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: context.accent),
                              onPressed: () => _showBillSheet(context, bill: bill),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: context.fgMuted),
                              onPressed: () => _confirmDelete(context, bill.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.soft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Next: ${DateFormat('MMM d, yyyy').format(bill.dueDate)}',
                                style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, fontSize: 13, color: context.onSoft),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgent ? AppTheme.ink : AppTheme.lime,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                ),
                                child: Text(
                                  statusText,
                                  style: GoogleFonts.urbanist(
                                      fontWeight: FontWeight.w700, fontSize: 12, color: urgent ? AppTheme.white : AppTheme.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
