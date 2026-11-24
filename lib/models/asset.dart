class Asset {
  final String id;
  final String name;
  final double value;

  Asset({
    required this.id,
    required this.name,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      name: map['name'],
      value: map['value'],
    );
  }
}
