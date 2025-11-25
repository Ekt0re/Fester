// lib/services/SupabaseServicies/models/sottogruppo.dart
class Sottogruppo {
  final int id;
  final String name;
  final int gruppoId;
  final String eventId;
  final DateTime? createdAt;

  Sottogruppo({
    required this.id,
    required this.name,
    required this.gruppoId,
    required this.eventId,
    this.createdAt,
  });

  factory Sottogruppo.fromJson(Map<String, dynamic> json) {
    return Sottogruppo(
      id: json['id'] as int,
      name: json['name'] as String,
      gruppoId: json['gruppo_id'] as int,
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
      'gruppo_id': gruppoId,
      'event_id': eventId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
