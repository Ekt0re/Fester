import 'package:equatable/equatable.dart';
import 'package:fester_frontend/models/rule.dart';

class Event extends Equatable {
  final String id;
  final String name;
  final String place;
  final DateTime dateTime;
  final List<Rule> rules;
  final String createdBy;
  final String state;
  final DateTime createdAt;
  final String? role;
  final EventStats? stats;

  const Event({
    required this.id,
    required this.name,
    required this.place,
    required this.dateTime,
    required this.rules,
    required this.createdBy,
    required this.state,
    required this.createdAt,
    this.role,
    this.stats,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Gestione specifica per il campo rules come JSONB
    List<Rule> parseRules(dynamic rulesData) {
      if (rulesData == null) return [];
      if (rulesData is List) {
        return rulesData
            .map((e) => Rule.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (rulesData is Map<String, dynamic>) {
        return [Rule.fromJson(rulesData)];
      }
      return [];
    }

    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      place: json['place'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      rules: parseRules(json['rules']),
      createdBy: json['created_by'] as String,
      state: json['state'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      role: json['role'] as String?,
      stats: json['stats'] != null ? EventStats.fromJson(json['stats'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'place': place,
    'date_time': dateTime.toIso8601String(),
    'rules': rules.map((r) => r.toJson()).toList(),
    'created_by': createdBy,
    'state': state,
    'created_at': createdAt.toIso8601String(),
    if (role != null) 'role': role,
    if (stats != null) 'stats': stats!.toJson(),
  };

  Event copyWith({
    String? id,
    String? name,
    String? place,
    DateTime? dateTime,
    List<Rule>? rules,
    String? createdBy,
    String? state,
    DateTime? createdAt,
    String? role,
    EventStats? stats,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      place: place ?? this.place,
      dateTime: dateTime ?? this.dateTime,
      rules: rules ?? this.rules,
      createdBy: createdBy ?? this.createdBy,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    place,
    dateTime,
    rules,
    createdBy,
    state,
    createdAt,
    role,
    stats,
  ];
}

/// Classe per gestire le statistiche dell'evento
class EventStats extends Equatable {
  final int total;
  final int invited;
  final int confirmed;
  final int present;

  const EventStats({
    required this.total,
    required this.invited,
    required this.confirmed,
    required this.present,
  });

  factory EventStats.fromJson(Map<String, dynamic> json) {
    return EventStats(
      total: json['total'] as int? ?? 0,
      invited: json['invited'] as int? ?? 0,
      confirmed: json['confirmed'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'invited': invited,
    'confirmed': confirmed,
    'present': present,
  };

  EventStats copyWith({
    int? total,
    int? invited,
    int? confirmed,
    int? present,
  }) {
    return EventStats(
      total: total ?? this.total,
      invited: invited ?? this.invited,
      confirmed: confirmed ?? this.confirmed,
      present: present ?? this.present,
    );
  }

  @override
  List<Object?> get props => [total, invited, confirmed, present];
} 