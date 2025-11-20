// lib/models/participation_status_history.dart
class ParticipationStatusHistory {
  final String id;
  final String participationId;
  final int statusId;
  final String? changedBy;
  final String? notes;
  final DateTime createdAt;

  ParticipationStatusHistory({
    required this.id,
    required this.participationId,
    required this.statusId,
    this.changedBy,
    this.notes,
    required this.createdAt,
  });

  factory ParticipationStatusHistory.fromJson(Map<String, dynamic> json) {
    return ParticipationStatusHistory(
      id: json['id'] as String,
      participationId: json['participation_id'] as String,
      statusId: json['status_id'] as int,
      changedBy: json['changed_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participation_id': participationId,
      'status_id': statusId,
      'changed_by': changedBy,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
