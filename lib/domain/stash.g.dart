// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'stash.dart';

class StashAdapter extends TypeAdapter<Stash> {
  @override
  final int typeId = 13;

  @override
  Stash read(BinaryReader reader) {
    return Stash(
      id: reader.readString(),
      itemId: reader.readString(),
      placeName: reader.readString(),
      placeHint: reader.readBool() ? reader.readString() : null,
      photo: reader.readBool() ? reader.readString() : null,
      storedOn: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      lastChecked: reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null,
    );
  }

  @override
  void write(BinaryWriter writer, Stash obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.itemId);
    writer.writeString(obj.placeName);
    writer.writeBool(obj.placeHint != null);
    if (obj.placeHint != null) writer.writeString(obj.placeHint!);
    writer.writeBool(obj.photo != null);
    if (obj.photo != null) writer.writeString(obj.photo!);
    writer.writeInt(obj.storedOn.millisecondsSinceEpoch);
    writer.writeBool(obj.lastChecked != null);
    if (obj.lastChecked != null) writer.writeInt(obj.lastChecked!.millisecondsSinceEpoch);
  }
}
