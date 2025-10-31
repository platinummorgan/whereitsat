import 'package:hive/hive.dart';
// ...existing code...
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
// ...existing code...

class ItemRepo {
  final Box<Item> box;
  ItemRepo(this.box);

  Future<void> add(Item item) async {
    if (item.name.trim().isEmpty) throw Exception('Item name required');
    await box.put(item.id, item);
  }

  Future<void> update(Item item) async {
    if (item.name.trim().isEmpty) throw Exception('Item name required');
    await box.put(item.id, item);
  }

  Future<void> delete(String id) async => await box.delete(id);
  Item? get(String id) => box.get(id);
  List<Item> list() => box.values.toList();
}

class LoanRepo {
  Future<void> deleteLoan(String id) async {
    await box.delete(id);
  }

  Future<void> undoDelete(Loan loan) async {
    await box.put(loan.id, loan);
  }

  Future<void> undoMarkReturned(String id) async {
    final loan = box.get(id);
    if (loan == null) return;
    final updated = Loan(
      id: loan.id,
      itemId: loan.itemId,
      person: loan.person,
      contact: loan.contact,
      lentOn: loan.lentOn,
      dueOn: loan.dueOn,
      status: LoanStatus.out,
      notes: loan.notes,
      returnPhoto: loan.returnPhoto,
      returnedOn: null,
    );
    await box.put(id, updated);
  }
  final Box<Loan> box;
  LoanRepo(this.box);

  Future<void> addLoan(Loan loan) async {
    if (loan.person.trim().isEmpty) throw Exception('Person required');
    await box.put(loan.id, loan);
  }

  Future<void> markReturned(String id, {String? returnPhotoPath, DateTime? returnedOn}) async {
    final loan = box.get(id);
    if (loan == null) return;
    final now = returnedOn ?? DateTime.now();
    final updated = Loan(
      id: loan.id,
      itemId: loan.itemId,
      person: loan.person,
      contact: loan.contact,
      lentOn: loan.lentOn,
      dueOn: loan.dueOn,
      status: LoanStatus.returned,
      notes: loan.notes,
      returnPhoto: returnPhotoPath ?? loan.returnPhoto,
      returnedOn: now,
      where: loan.where,
      category: loan.category,
    );
    await box.put(id, updated);
  }

  List<Loan> listOverdue(DateTime now) => box.values.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList();
  List<Loan> listOutSorted() => box.values.where((l) => l.status == LoanStatus.out).toList()
    ..sort((a, b) => ((a.dueOn ?? a.lentOn).compareTo(b.dueOn ?? b.lentOn)));
  List<Loan> listReturnedSorted() => box.values.where((l) => l.status == LoanStatus.returned).toList()
    ..sort((a, b) => (b.returnedOn ?? DateTime(0)).compareTo(a.returnedOn ?? DateTime(0)));

  // Removed duplicate markReturned and listOut
}

class StashRepo {
  List<String> recentPlaces([int count = 8]) {
    final all = box.values.map((s) => s.placeName).toSet().toList();
    return all.take(count).toList();
  }
  final Box<Stash> box;
  StashRepo(this.box);

  Future<void> add(Stash stash) async {
    await box.put(stash.id, stash);
  }

  Future<void> markFound(String id, {DateTime? lastChecked}) async {
    final stash = box.get(id);
    if (stash == null) return;
    final timestamp = lastChecked ?? DateTime.now();
    final updated = Stash(
      id: stash.id,
      itemId: stash.itemId,
      placeName: stash.placeName,
      placeHint: stash.placeHint,
      photo: stash.photo,
      storedOn: stash.storedOn,
      lastChecked: timestamp,
      returnedOn: stash.returnedOn ?? timestamp,
    );
    await box.put(id, updated);
  }

  List<Stash> listRecent([int count = 10]) {
    final sorted = box.values.toList()
      ..sort((a, b) => (b.lastChecked ?? b.storedOn).compareTo(a.lastChecked ?? a.storedOn));
    return sorted.take(count).toList();
  }
}
