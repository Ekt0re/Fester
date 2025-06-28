import 'dart:developer';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'guest.g.dart';

@HiveType(typeId: 2)
class Guest extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String surname;

  @HiveField(3)
  final String code;

  @HiveField(4)
  final String qrCode;

  @HiveField(5)
  final String barcode;

  @HiveField(6)
  final GuestStatus status;

  @HiveField(7)
  final int drinksCount;

  @HiveField(8)
  final List<String> flags;

  @HiveField(9)
  final String? invitedBy;

  @HiveField(10)
  final DateTime lastUpdated;

  @HiveField(11)
  final String eventId;

  Guest({
    String? id,
    required this.name,
    required this.surname,
    required this.code,
    required this.qrCode,
    required this.barcode,
    this.status = GuestStatus.notArrived,
    this.drinksCount = 0,
    this.flags = const [],
    this.invitedBy,
    DateTime? lastUpdated,
    required this.eventId,
  }) : 
    id = id ?? const Uuid().v4(),
    lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'surname': surname,
    'code': code,
    'qr_code': qrCode,
    'barcode': barcode,
    'status': statusToDb(status),
    'drinks_count': drinksCount,
    'flags': flags,
    if (invitedBy != null && invitedBy!.isNotEmpty) 'invited_by': invitedBy,
    'last_updated': lastUpdated.toIso8601String(),
    'event_id': int.tryParse(eventId) ?? eventId,
  };

  factory Guest.fromJson(Map<String, dynamic> json) => Guest(
    id: json['id']?.toString() ?? const Uuid().v4(),
    name: json['name']?.toString() ?? '',
    surname: json['surname']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    qrCode: json['qr_code']?.toString() ?? '',
    barcode: json['barcode']?.toString() ?? '',
    status: statusFromDb(json['status']?.toString()),
    drinksCount: json['drinks_count'] ?? 0,
    flags: json['flags'] != null ? List<String>.from(json['flags']) : <String>[],
    invitedBy: json['invited_by']?.toString(),
    lastUpdated: json['last_updated'] != null 
        ? DateTime.tryParse(json['last_updated']) ?? DateTime.now()
        : DateTime.now(),
    eventId: json['event_id']?.toString() ?? '1',
  );

  // --- Helper per conversione stato <-> Supabase enum ---
  static String statusToDb(GuestStatus status) {
    switch (status) {
      case GuestStatus.notArrived:
        return 'not_arrived';
      case GuestStatus.arrived:
        return 'arrived';
      case GuestStatus.left:
        return 'left';
    }
  }

  static GuestStatus statusFromDb(String? value) {
    if (value == null) return GuestStatus.notArrived;
    
    switch (value.toLowerCase()) {
      case 'not_arrived':
        return GuestStatus.notArrived;
      case 'arrived':
        return GuestStatus.arrived;
      case 'left':
        return GuestStatus.left;
      default:
        // fallback per valori sconosciuti
        log('Unknown guest status: $value, defaulting to not_arrived');
        return GuestStatus.notArrived;
    }
  }
}

@HiveType(typeId: 3)
enum GuestStatus {
  @HiveField(0)
  notArrived,
  @HiveField(1)
  arrived,
  @HiveField(2)
  left
}
