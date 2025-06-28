import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'event.g.dart';

@HiveType(typeId: 1)
class Event extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String location;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final int maxGuests;

  @HiveField(6)
  final String status; // 'active', 'cancelled', 'completed'

  @HiveField(7)
  final String? hostId;

  @HiveField(8)
  final DateTime lastUpdated;

  Event({
    String? id,
    required this.name,
    required this.date,
    required this.location,
    this.description,
    this.maxGuests = 50,
    this.status = 'active',
    this.hostId,
    DateTime? lastUpdated,
  }) : 
    id = id ?? const Uuid().v4(),
    lastUpdated = lastUpdated ?? DateTime.now();

  // Compatibilità con schema Supabase
  Map<String, dynamic> toSupabaseJson() => {
    'name': name,
    'date': date.toIso8601String(),
    'location': location,
    'description': description,
    'max_guests': maxGuests,
    'status': status,
    'host_id': hostId,
  };

  // Per database locale Hive
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'location': location,
    'description': description,
    'max_guests': maxGuests,
    'status': status,
    'host_id': hostId,
    'last_updated': lastUpdated.toIso8601String(),
  };

  // Da Supabase response
  factory Event.fromSupabaseJson(Map<String, dynamic> json) => Event(
    id: json['id']?.toString() ?? const Uuid().v4(),
    name: json['name']?.toString() ?? '',
    date: json['date'] != null 
        ? DateTime.tryParse(json['date']) ?? DateTime.now()
        : DateTime.now(),
    location: json['location']?.toString() ?? '',
    description: json['description']?.toString(),
    maxGuests: json['max_guests'] ?? 50,
    status: json['status']?.toString() ?? 'active',
    hostId: json['host_id']?.toString(),
    lastUpdated: json['updated_at'] != null 
        ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
        : DateTime.now(),
  );

  // Da JSON locale
  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id']?.toString() ?? const Uuid().v4(),
    name: json['name']?.toString() ?? '',
    date: json['date'] != null 
        ? DateTime.tryParse(json['date']) ?? DateTime.now()
        : DateTime.now(),
    location: json['location']?.toString() ?? '',
    description: json['description']?.toString(),
    maxGuests: json['max_guests'] ?? 50,
    status: json['status']?.toString() ?? 'active',
    hostId: json['host_id']?.toString(),
    lastUpdated: json['last_updated'] != null 
        ? DateTime.tryParse(json['last_updated']) ?? DateTime.now()
        : DateTime.now(),
  );
}
