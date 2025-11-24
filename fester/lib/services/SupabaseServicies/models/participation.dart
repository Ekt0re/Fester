// lib/models/participation.dart
class Participation {
  final String id;
  final String personId;
  final String eventId;
  final int statusId;
  final int? roleId;
  final String? invitedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? person;

  Participation({
    required this.id,
    required this.personId,
    required this.eventId,
    required this.statusId,
    this.roleId,
    this.invitedBy,
    required this.createdAt,
    this.updatedAt,
    this.person,
  });

  factory Participation.fromJson(Map<String, dynamic> json) {
    return Participation(
      id: json['id'] as String,
      personId: json['person_id'] as String,
      eventId: json['event_id'] as String,
      statusId: json['status_id'] as int,
      roleId: json['role_id'] as int?,
      invitedBy: json['invited_by'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      person: json['person'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'person_id': personId,
      'event_id': eventId,
      'status_id': statusId,
      'role_id': roleId,
      'invited_by': invitedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
