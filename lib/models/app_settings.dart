import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 5)
enum DatabaseMode {
  @HiveField(0)
  supabase,
  @HiveField(1)
  mongodb,
}

@HiveType(typeId: 6)
class AppSettings extends HiveObject {
  @HiveField(0)
  final DatabaseMode databaseMode;
  
  @HiveField(1)
  final String? mongoDbHost;
  
  @HiveField(2)
  final int? mongoDbPort;
  
  @HiveField(3)
  final String? jwtToken;
  
  @HiveField(4)
  final bool useRealAuth;
  
  @HiveField(5)
  final String? lastSyncTime;

  AppSettings({
    this.databaseMode = DatabaseMode.supabase,
    this.mongoDbHost,
    this.mongoDbPort = 27017,
    this.jwtToken,
    this.useRealAuth = true,
    this.lastSyncTime,
  });

  AppSettings copyWith({
    DatabaseMode? databaseMode,
    String? mongoDbHost,
    int? mongoDbPort,
    String? jwtToken,
    bool? useRealAuth,
    String? lastSyncTime,
  }) {
    return AppSettings(
      databaseMode: databaseMode ?? this.databaseMode,
      mongoDbHost: mongoDbHost ?? this.mongoDbHost,
      mongoDbPort: mongoDbPort ?? this.mongoDbPort,
      jwtToken: jwtToken ?? this.jwtToken,
      useRealAuth: useRealAuth ?? this.useRealAuth,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  String get mongoConnectionString => 
      'mongodb://${mongoDbHost ?? 'localhost'}:${mongoDbPort ?? 27017}';

  Map<String, dynamic> toJson() {
    return {
      'databaseMode': databaseMode.name,
      'mongoDbHost': mongoDbHost,
      'mongoDbPort': mongoDbPort,
      'jwtToken': jwtToken,
      'useRealAuth': useRealAuth,
      'lastSyncTime': lastSyncTime,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      databaseMode: DatabaseMode.values.firstWhere(
        (mode) => mode.name == json['databaseMode'],
        orElse: () => DatabaseMode.supabase,
      ),
      mongoDbHost: json['mongoDbHost'],
      mongoDbPort: json['mongoDbPort'],
      jwtToken: json['jwtToken'],
      useRealAuth: json['useRealAuth'] ?? true,
      lastSyncTime: json['lastSyncTime'],
    );
  }
} 