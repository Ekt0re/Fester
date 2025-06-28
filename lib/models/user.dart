import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String passwordHash;

  @HiveField(3)
  final String eventId;

  @HiveField(4)
  final UserRole role;

  @HiveField(5)
  final DateTime lastUpdated;

  User({
    String? id,
    required this.username,
    required this.passwordHash,
    required this.eventId,
    required this.role,
    DateTime? lastUpdated,
  }) : 
    id = id ?? const Uuid().v4(),
    lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password_hash': passwordHash,
    'event_id': eventId,
    'role': role.name,
    'last_updated': lastUpdated.toIso8601String(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id']?.toString() ?? const Uuid().v4(),
    username: json['username']?.toString() ?? '',
    passwordHash: json['password_hash']?.toString() ?? '',
    eventId: json['event_id']?.toString() ?? '1',
    role: UserRole.values.firstWhere(
      (r) => r.name == json['role']?.toString(),
      orElse: () => UserRole.staff,
    ),
    lastUpdated: json['last_updated'] != null 
        ? DateTime.tryParse(json['last_updated']) ?? DateTime.now()
        : DateTime.now(),
  );
}

@HiveType(typeId: 4)
enum UserRole {
  @HiveField(0)
  host,
  @HiveField(1)
  staff
}
