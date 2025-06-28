// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 6;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      databaseMode: fields[0] as DatabaseMode? ?? DatabaseMode.supabase,
      mongoDbHost: fields[1] as String?,
      mongoDbPort: fields[2] as int?,
      jwtToken: fields[3] as String?,
      useRealAuth: fields[4] as bool? ?? true,
      lastSyncTime: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.databaseMode)
      ..writeByte(1)
      ..write(obj.mongoDbHost)
      ..writeByte(2)
      ..write(obj.mongoDbPort)
      ..writeByte(3)
      ..write(obj.jwtToken)
      ..writeByte(4)
      ..write(obj.useRealAuth)
      ..writeByte(5)
      ..write(obj.lastSyncTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DatabaseModeAdapter extends TypeAdapter<DatabaseMode> {
  @override
  final int typeId = 5;

  @override
  DatabaseMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DatabaseMode.supabase;
      case 1:
        return DatabaseMode.mongodb;
      default:
        return DatabaseMode.supabase;
    }
  }

  @override
  void write(BinaryWriter writer, DatabaseMode obj) {
    switch (obj) {
      case DatabaseMode.supabase:
        writer.writeByte(0);
        break;
      case DatabaseMode.mongodb:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatabaseModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
