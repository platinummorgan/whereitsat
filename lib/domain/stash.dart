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
  @HiveField(7)
  final DateTime? returnedOn;

  Stash({
    required this.id,
    required this.itemId,
    required this.placeName,
    this.placeHint,
    this.photo,
    required this.storedOn,
    this.lastChecked,
    this.returnedOn,
  });

  factory Stash.fromJson(Map<String, dynamic> json) {
    return Stash(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      placeName: json['placeName'] as String,
      placeHint: json['placeHint'] as String?,
      photo: json['photo'] as String?,
      storedOn: DateTime.parse(json['storedOn'] as String),
      lastChecked: json['lastChecked'] != null ? DateTime.parse(json['lastChecked'] as String) : null,
      returnedOn: json['returnedOn'] != null ? DateTime.parse(json['returnedOn'] as String) : null,
    );
  }
}
