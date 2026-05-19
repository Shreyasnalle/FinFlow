import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final double amount;
  @HiveField(2)
  final DateTime date;
  @HiveField(3)
  final String category;
  @HiveField(4)
  final String note;
  @HiveField(5)
  final bool isIncome;
  @HiveField(6)
  final bool isInvestment;

  Transaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
    required this.isIncome,
    this.isInvestment = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
      'isIncome': isIncome,
      'isInvestment': isInvestment,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
      note: map['note'] ?? '',
      isIncome: map['isIncome'],
      isInvestment: map['isInvestment'] ?? false,
    );
  }
}
