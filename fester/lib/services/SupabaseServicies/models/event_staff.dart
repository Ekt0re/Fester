import 'staff_user.dart';

class EventStaff {
  final String id;
  final String eventId;
  final String? staffUserId;
  final int roleId;
  final String? roleName;
  final String? mail;
  final String? assignedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final StaffUser? staff; // Added field

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
    this.staff,
  });

  factory EventStaff.fromJson(Map<String, dynamic> json) {
    return EventStaff(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      staffUserId: json['staff_user_id'] as String?,
      roleId: json['role_id'] as int,
      roleName: (json['role'] as Map<String, dynamic>?)?['name'] as String?,
      mail: json['mail'] as String?,
      assignedBy: json['assigned_by'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      staff: json['staff'] != null ? StaffUser.fromJson(json['staff']) : null,
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
      // staff is usually not serialized back to DB in this context
    };
  }
}

