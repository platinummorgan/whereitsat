import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 10)
class Item extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String? category;
  @HiveField(3)
  final List<String> photos;
  @HiveField(4)
  final List<String> tags;
  @HiveField(5)
  final DateTime createdAt;
  @HiveField(6)
  final DateTime updatedAt;

  Item({
    required this.id,
    required this.name,
    this.category,
    List<String>? photos,
    List<String>? tags,
    required this.createdAt,
    required this.updatedAt,
  })  : photos = photos ?? [],
        tags = tags ?? [];

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      photos: (json['photos'] as List<dynamic>?)?.map((e) => e as String).toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
