import 'package:hive/hive.dart';

part 'loan.g.dart';

@HiveType(typeId: 11)
enum LoanStatus {
  @HiveField(0)
  out,
  @HiveField(1)
  returned,
}

@HiveType(typeId: 12)
class Loan extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String itemId;
  @HiveField(2)
  final String person;
  @HiveField(3)
  final String? contact;
  @HiveField(4)
  final DateTime lentOn;
  @HiveField(5)
  final DateTime? dueOn;
  @HiveField(6)
  final LoanStatus status;
  @HiveField(7)
  final String? notes;
  @HiveField(8)
  final String? returnPhoto;
  @HiveField(9)
  final DateTime? returnedOn;

  Loan({
    required this.id,
    required this.itemId,
    required this.person,
    this.contact,
    required this.lentOn,
    this.dueOn,
    required this.status,
    this.notes,
    this.returnPhoto,
    this.returnedOn,
  });
}
