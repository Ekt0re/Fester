// lib/models/staff_user.dart
class StaffUser {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? email;
  final String? phone;
  final String? imagePath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  StaffUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.email,
    this.phone,
    this.imagePath,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  String get fullName => '$firstName $lastName';

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  StaffUser copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? email,
    String? phone,
    String? imagePath,
    bool? isActive,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return StaffUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
