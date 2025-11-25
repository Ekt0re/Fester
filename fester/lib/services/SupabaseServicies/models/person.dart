// lib/models/person.dart
class Person {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? email;
  final String? phone;
  final String? imagePath;
  final String? idEvent;
  final String? codiceFiscale;
  final String? indirizzo;
  final int? gruppoId;
  final int? sottogruppoId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.email,
    this.phone,
    this.imagePath,
    this.idEvent,
    this.codiceFiscale,
    this.indirizzo,
    this.gruppoId,
    this.sottogruppoId,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  String get fullName => '$firstName $lastName';

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      dateOfBirth:
          json['date_of_birth'] != null
              ? DateTime.parse(json['date_of_birth'])
              : null,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      imagePath: json['image_path'] as String?,
      idEvent: json['id_event'] as String?,
      codiceFiscale: json['codice_fiscale'] as String?,
      indirizzo: json['indirizzo'] as String?,
      gruppoId: json['gruppo_id'] as int?,
      sottogruppoId: json['sottogruppo_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      deletedAt:
          json['deleted_at'] != null
              ? DateTime.parse(json['deleted_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'email': email,
      'phone': phone,
      'image_path': imagePath,
      'id_event': idEvent,
      'codice_fiscale': codiceFiscale,
      'indirizzo': indirizzo,
      'gruppo_id': gruppoId,
      'sottogruppo_id': sottogruppoId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
