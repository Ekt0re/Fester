// lib/models/transaction.dart
class Transaction {
  final String id;
  final String participationId;
  final int transactionTypeId;
  final String? menuItemId;
  final String? name;
  final String? description;
  final double amount;
  final int quantity;
  final String createdBy;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.participationId,
    required this.transactionTypeId,
    this.menuItemId,
    this.name,
    this.description,
    this.amount = 0.0,
    this.quantity = 1,
    required this.createdBy,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      participationId: json['participation_id'] as String,
      transactionTypeId: json['transaction_type_id'] as int,
      menuItemId: json['menu_item_id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participation_id': participationId,
      'transaction_type_id': transactionTypeId,
      'menu_item_id': menuItemId,
      'name': name,
      'description': description,
      'amount': amount,
      'quantity': quantity,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
