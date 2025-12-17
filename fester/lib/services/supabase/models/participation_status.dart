// lib/models/participation_status.dart
class ParticipationStatus {
  final int id;
  final String name;
  final String? description;
  final bool isInside;
  final DateTime createdAt;

  ParticipationStatus({
    required this.id,
    required this.name,
    this.description,
    required this.isInside,
    required this.createdAt,
  });

  factory ParticipationStatus.fromJson(Map<String, dynamic> json) {
    return ParticipationStatus(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isInside: json['is_inside'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_inside': isInside,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
