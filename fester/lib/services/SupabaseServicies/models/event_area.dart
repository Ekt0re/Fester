class EventArea {
  final String id;
  final String eventId;
  final String name;
  final int currentCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventArea({
    required this.id,
    required this.eventId,
    required this.name,
    required this.currentCount,
    this.createdAt,
    this.updatedAt,
  });

  factory EventArea.fromJson(Map<String, dynamic> json) {
    return EventArea(
      id: json['id'],
      eventId: json['event_id'],
      name: json['name'],
      currentCount: json['current_count'] ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
    );
  }
}
