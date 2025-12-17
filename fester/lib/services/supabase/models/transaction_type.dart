// lib/models/transaction_type.dart
class TransactionType {
  final int id;
  final String name;
  final String? description;
  final bool affectsDrinkCount;
  final bool isMonetary;
  final DateTime createdAt;

  TransactionType({
    required this.id,
    required this.name,
    this.description,
    required this.affectsDrinkCount,
    required this.isMonetary,
    required this.createdAt,
  });

  factory TransactionType.fromJson(Map<String, dynamic> json) {
    return TransactionType(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      affectsDrinkCount: json['affects_drink_count'] as bool? ?? false,
      isMonetary: json['is_monetary'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'affects_drink_count': affectsDrinkCount,
      'is_monetary': isMonetary,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
