// lib/models/menu.dart
class Menu {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Menu({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
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
      'event_id': eventId,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
