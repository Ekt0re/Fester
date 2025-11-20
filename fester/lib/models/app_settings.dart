import 'package:flutter/material.dart';

/// Enum per il livello di notifiche
enum NotificationLevel {
  all,
  important,
  off;

  String get displayName {
    switch (this) {
      case NotificationLevel.all:
        return 'Tutte';
      case NotificationLevel.important:
        return 'Solo importanti';
      case NotificationLevel.off:
        return 'Silenzioso';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationLevel.all:
        return Icons.notifications;
      case NotificationLevel.important:
        return Icons.notification_important;
      case NotificationLevel.off:
        return Icons.notifications_off;
    }
  }
}

/// Modello per le impostazioni dell'applicazione
class AppSettings {
  String language;
  ThemeMode themeMode;
  NotificationLevel notificationLevel;
  bool vibrationEnabled;

  AppSettings({
    this.language = 'it',
    this.themeMode = ThemeMode.system,
    this.notificationLevel = NotificationLevel.all,
    this.vibrationEnabled = true,
  });

  /// Converte le impostazioni in JSON
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'themeMode': themeMode.name,
      'notificationLevel': notificationLevel.name,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  /// Crea un'istanza da JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      language: json['language'] as String? ?? 'it',
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      notificationLevel: NotificationLevel.values.firstWhere(
        (e) => e.name == json['notificationLevel'],
        orElse: () => NotificationLevel.all,
      ),
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    );
  }

  /// Crea una copia con modifiche
  AppSettings copyWith({
    String? language,
    ThemeMode? themeMode,
    NotificationLevel? notificationLevel,
    bool? vibrationEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      notificationLevel: notificationLevel ?? this.notificationLevel,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  /// Impostazioni di default
  static AppSettings get defaultSettings => AppSettings();
}
