// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final int typeId = 12;

  @override
  Loan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Loan(
      id: fields[0] as String,
      itemId: fields[1] as String,
      person: fields[2] as String,
      contact: fields[3] as String?,
      lentOn: fields[4] as DateTime,
      dueOn: fields[5] as DateTime?,
      status: fields[6] as LoanStatus,
      notes: fields[7] as String?,
      returnPhoto: fields[8] as String?,
      returnedOn: fields[9] as DateTime?,
      where: fields[10] as String?,
      category: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.person)
      ..writeByte(3)
      ..write(obj.contact)
      ..writeByte(4)
      ..write(obj.lentOn)
      ..writeByte(5)
      ..write(obj.dueOn)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.returnPhoto)
      ..writeByte(9)
      ..write(obj.returnedOn)
      ..writeByte(10)
      ..write(obj.where)
      ..writeByte(11)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoanStatusAdapter extends TypeAdapter<LoanStatus> {
  @override
  final int typeId = 11;

  @override
  LoanStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LoanStatus.out;
      case 1:
        return LoanStatus.returned;
      default:
        return LoanStatus.out;
    }
  }

  @override
  void write(BinaryWriter writer, LoanStatus obj) {
    switch (obj) {
      case LoanStatus.out:
        writer.writeByte(0);
        break;
      case LoanStatus.returned:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
