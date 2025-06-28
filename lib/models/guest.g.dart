// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GuestAdapter extends TypeAdapter<Guest> {
  @override
  final int typeId = 2;

  @override
  Guest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Guest(
      id: fields[0] as String?,
      name: fields[1] as String? ?? '',
      surname: fields[2] as String? ?? '',
      code: fields[3] as String? ?? '',
      qrCode: fields[4] as String? ?? '',
      barcode: fields[5] as String? ?? '',
      status: fields[6] as GuestStatus? ?? GuestStatus.notArrived,
      drinksCount: fields[7] as int? ?? 0,
      flags: (fields[8] as List?)?.cast<String>() ?? <String>[],
      invitedBy: fields[9] as String?,
      lastUpdated: fields[10] as DateTime?,
      eventId: fields[11] as String? ?? '1',
    );
  }

  @override
  void write(BinaryWriter writer, Guest obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.surname)
      ..writeByte(3)
      ..write(obj.code)
      ..writeByte(4)
      ..write(obj.qrCode)
      ..writeByte(5)
      ..write(obj.barcode)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.drinksCount)
      ..writeByte(8)
      ..write(obj.flags)
      ..writeByte(9)
      ..write(obj.invitedBy)
      ..writeByte(10)
      ..write(obj.lastUpdated)
      ..writeByte(11)
      ..write(obj.eventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GuestStatusAdapter extends TypeAdapter<GuestStatus> {
  @override
  final int typeId = 3;

  @override
  GuestStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GuestStatus.notArrived;
      case 1:
        return GuestStatus.arrived;
      case 2:
        return GuestStatus.left;
      default:
        return GuestStatus.notArrived;
    }
  }

  @override
  void write(BinaryWriter writer, GuestStatus obj) {
    switch (obj) {
      case GuestStatus.notArrived:
        writer.writeByte(0);
        break;
      case GuestStatus.arrived:
        writer.writeByte(1);
        break;
      case GuestStatus.left:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuestStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
