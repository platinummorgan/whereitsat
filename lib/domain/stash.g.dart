// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stash.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StashAdapter extends TypeAdapter<Stash> {
  @override
  final int typeId = 13;

  @override
  Stash read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Stash(
      id: fields[0] as String,
      itemId: fields[1] as String,
      placeName: fields[2] as String,
      placeHint: fields[3] as String?,
      photo: fields[4] as String?,
      storedOn: fields[5] as DateTime,
      lastChecked: fields[6] as DateTime?,
      returnedOn: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Stash obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.placeName)
      ..writeByte(3)
      ..write(obj.placeHint)
      ..writeByte(4)
      ..write(obj.photo)
      ..writeByte(5)
      ..write(obj.storedOn)
      ..writeByte(6)
      ..write(obj.lastChecked)
      ..writeByte(7)
      ..write(obj.returnedOn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StashAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
