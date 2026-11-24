class RecurringBill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;

  RecurringBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      dueDate: DateTime.parse(map['dueDate']),
    );
  }
}
