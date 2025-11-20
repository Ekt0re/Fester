// lib/models/event_staff.dart
class EventStaff {
  final String id;
  final String eventId;
  final String? staffUserId;
  final int roleId;
  final String? roleName; // Added field
  final String? mail;
  final String? assignedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EventStaff({
    required this.id,
    required this.eventId,
    this.staffUserId,
    required this.roleId,
    this.roleName,
    this.mail,
    this.assignedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory EventStaff.fromJson(Map<String, dynamic> json) {
    return EventStaff(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      staffUserId: json['staff_user_id'] as String?,
      roleId: json['role_id'] as int,
      // Extract role name from nested role object if available
      roleName: (json['role'] as Map<String, dynamic>?)?['name'] as String?,
      mail: json['mail'] as String?,
      assignedBy: json['assigned_by'] as String?,
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
      'staff_user_id': staffUserId,
      'role_id': roleId,
      'role_name': roleName,
      'mail': mail,
      'assigned_by': assignedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
