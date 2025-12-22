// lib/models/event_settings.dart
class EventSettings {
  final String id;
  final String eventId;
  final int? maxParticipants;
  final bool allowGuests;
  final String? location;
  final String currency;
  final DateTime startAt;
  final DateTime? endAt;
  final DateTime? checkInStartTime;
  final DateTime? checkInEndTime;
  final bool lateEntryAllowed;
  final int? ageRestriction;
  final bool idCheckRequired;
  final int maxWarningsBeforeBan;
  final int? defaultMaxDrinksPerPerson;
  final Map<String, dynamic>? roleDrinkLimits;
  final Map<String, dynamic>? customSettings;
  final bool isActive;
  final bool specificPeopleCounting; // New field
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EventSettings({
    required this.id,
    required this.eventId,
    this.maxParticipants,
    this.allowGuests = true,
    this.location,
    this.currency = 'EUR',
    required this.startAt,
    this.endAt,
    this.checkInStartTime,
    this.checkInEndTime,
    this.lateEntryAllowed = true,
    this.ageRestriction,
    this.idCheckRequired = false,
    this.maxWarningsBeforeBan = 3,
    this.defaultMaxDrinksPerPerson,
    this.roleDrinkLimits,
    this.customSettings,
    this.isActive = true,
    this.specificPeopleCounting = false, // Default to false
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory EventSettings.fromJson(Map<String, dynamic> json) {
    return EventSettings(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      maxParticipants: json['max_participants'] as int?,
      allowGuests: json['allow_guests'] as bool? ?? true,
      location: json['location'] as String?,
      currency: json['currency'] as String? ?? 'EUR',
      startAt: DateTime.parse(json['start_at']),
      endAt: json['end_at'] != null ? DateTime.parse(json['end_at']) : null,
      checkInStartTime:
          json['check_in_start_time'] != null
              ? DateTime.parse(json['check_in_start_time'])
              : null,
      checkInEndTime:
          json['check_in_end_time'] != null
              ? DateTime.parse(json['check_in_end_time'])
              : null,
      lateEntryAllowed: json['late_entry_allowed'] as bool? ?? true,
      ageRestriction: json['age_restriction'] as int?,
      idCheckRequired: json['id_check_required'] as bool? ?? false,
      maxWarningsBeforeBan: json['max_warnings_before_ban'] as int? ?? 3,
      defaultMaxDrinksPerPerson: json['default_max_drinks_per_person'] as int?,
      roleDrinkLimits: json['role_drink_limits'] as Map<String, dynamic>?,
      customSettings: json['custom_settings'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      specificPeopleCounting:
          json['specific_people_counting'] as bool? ?? false,
      createdBy: json['created_by'] as String,
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
      'max_participants': maxParticipants,
      'allow_guests': allowGuests,
      'location': location,
      'currency': currency,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'check_in_start_time': checkInStartTime?.toIso8601String(),
      'check_in_end_time': checkInEndTime?.toIso8601String(),
      'late_entry_allowed': lateEntryAllowed,
      'age_restriction': ageRestriction,
      'id_check_required': idCheckRequired,
      'max_warnings_before_ban': maxWarningsBeforeBan,
      'default_max_drinks_per_person': defaultMaxDrinksPerPerson,
      'role_drink_limits': roleDrinkLimits,
      'custom_settings': customSettings,
      'is_active': isActive,
      'specific_people_counting': specificPeopleCounting,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
