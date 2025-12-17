// lib/models/menu_item.dart
class MenuItem {
  final String id;
  final String menuId;
  final int transactionTypeId;
  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final int sortOrder;
  final int? availableQuantity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MenuItem({
    required this.id,
    required this.menuId,
    required this.transactionTypeId,
    required this.name,
    this.description,
    required this.price,
    this.isAvailable = true,
    this.sortOrder = 0,
    this.availableQuantity,
    required this.createdAt,
    this.updatedAt,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      menuId: json['menu_id'] as String,
      transactionTypeId: json['transaction_type_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      availableQuantity: json['available_quantity'] as int?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_id': menuId,
      'transaction_type_id': transactionTypeId,
      'name': name,
      'description': description,
      'price': price,
      'is_available': isAvailable,
      'sort_order': sortOrder,
      'available_quantity': availableQuantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
