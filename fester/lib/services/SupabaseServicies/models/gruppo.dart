// lib/services/SupabaseServicies/models/gruppo.dart
class Gruppo {
  final int id;
  final String name;
  final String eventId;
  final DateTime? createdAt;

  Gruppo({
    required this.id,
    required this.name,
    required this.eventId,
    this.createdAt,
  });

  factory Gruppo.fromJson(Map<String, dynamic> json) {
    return Gruppo(
      id: json['id'] as int,
      name: json['name'] as String,
      eventId: json['event_id'] as String,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'event_id': eventId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
