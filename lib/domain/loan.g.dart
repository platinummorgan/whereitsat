// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'loan.dart';

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
    writer.writeByte(obj.index);
  }
}

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final int typeId = 12;

  @override
  Loan read(BinaryReader reader) {
    return Loan(
      id: reader.readString(),
      itemId: reader.readString(),
      person: reader.readString(),
      contact: reader.readBool() ? reader.readString() : null,
      lentOn: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      dueOn: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
      status: LoanStatusAdapter().read(reader),
      notes: reader.readBool() ? reader.readString() : null,
      returnPhoto: reader.readBool() ? reader.readString() : null,
      returnedOn: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.itemId);
    writer.writeString(obj.person);
    writer.writeBool(obj.contact != null);
    if (obj.contact != null) writer.writeString(obj.contact!);
    writer.writeInt(obj.lentOn.millisecondsSinceEpoch);
    writer.writeBool(obj.dueOn != null);
    if (obj.dueOn != null) writer.writeInt(obj.dueOn!.millisecondsSinceEpoch);
    LoanStatusAdapter().write(writer, obj.status);
    writer.writeBool(obj.notes != null);
    if (obj.notes != null) writer.writeString(obj.notes!);
    writer.writeBool(obj.returnPhoto != null);
    if (obj.returnPhoto != null) writer.writeString(obj.returnPhoto!);
    writer.writeBool(obj.returnedOn != null);
    if (obj.returnedOn != null) writer.writeInt(obj.returnedOn!.millisecondsSinceEpoch);
  }
}
