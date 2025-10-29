import 'package:hive/hive.dart';

part 'stash.g.dart';

@HiveType(typeId: 13)
class Stash extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String itemId;
  @HiveField(2)
  final String placeName;
  @HiveField(3)
  final String? placeHint;
  @HiveField(4)
  final String? photo;
  @HiveField(5)
  final DateTime storedOn;
  @HiveField(6)
  final DateTime? lastChecked;

  Stash({
    required this.id,
    required this.itemId,
    required this.placeName,
    this.placeHint,
    this.photo,
    required this.storedOn,
    this.lastChecked,
  });
}
