class Transaction {
  final String id;
  final double amount;
  final DateTime date;
  final String category;
  final String note;
  final bool isIncome;
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
