// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'item.dart';

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 10;

  @override
  Item read(BinaryReader reader) {
    return Item(
      id: reader.readString(),
      name: reader.readString(),
      category: reader.readBool() ? reader.readString() : null,
      photos: reader.readList().cast<String>(),
      tags: reader.readList().cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeBool(obj.category != null);
    if (obj.category != null) writer.writeString(obj.category!);
    writer.writeList(obj.photos);
    writer.writeList(obj.tags);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
