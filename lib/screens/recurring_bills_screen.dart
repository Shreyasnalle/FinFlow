import 'package:flutter/material.dart';
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
        title: const Text('Delete Bill'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      appBar: AppBar(
        title: const Text('Recurring Bills', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBillSheet(context),
        child: const Icon(Icons.add),
      ),
      body: provider.bills.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No recurring bills scheduled', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Automate your fixed bills here', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              itemCount: provider.bills.length,
              itemBuilder: (context, index) {
                final bill = provider.bills[index];
                
                // Calculate days remaining
                final difference = bill.dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
                Color statusColor = Colors.grey;
                String statusText = 'Due in $difference days';
                
                if (difference < 0) {
                  statusColor = Colors.red;
                  statusText = 'Overdue';
                } else if (difference == 0) {
                  statusColor = Colors.redAccent;
                  statusText = 'Due Today';
                } else if (difference <= 3) {
                  statusColor = Colors.orange;
                } else {
                  statusColor = Colors.green;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: 0.1),
                                    child: Icon(Icons.payment, color: statusColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bill.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currency.format(bill.amount),
                                        style: const TextStyle(color: AppTheme.brandDefault, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _showBillSheet(context, bill: bill),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _confirmDelete(context, bill.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Next: ${DateFormat('MMM d, yyyy').format(bill.dueDate)}',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodySmall?.color),
                                ),
                                Text(
                                  statusText,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ],
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
