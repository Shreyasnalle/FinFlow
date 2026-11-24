class FinancialGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;

  FinancialGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
    };
  }

  factory FinancialGoal.fromMap(Map<String, dynamic> map) {
    return FinancialGoal(
      id: map['id'],
      title: map['title'],
      targetAmount: map['targetAmount'],
      savedAmount: map['savedAmount'] ?? 0.0,
    );
  }
}
