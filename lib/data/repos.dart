import 'package:hive/hive.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

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
  final Box<Loan> box;
  LoanRepo(this.box);

  Future<void> add(Loan loan) async {
    if (loan.person.trim().isEmpty) throw Exception('Person required');
    await box.put(loan.id, loan);
  }

  Future<void> markReturned(String id, {String? returnPhoto, DateTime? returnedOn}) async {
    final loan = box.get(id);
    if (loan == null) return;
    final updated = Loan(
      id: loan.id,
      itemId: loan.itemId,
      person: loan.person,
      contact: loan.contact,
      lentOn: loan.lentOn,
      dueOn: loan.dueOn,
      status: LoanStatus.returned,
      notes: loan.notes,
      returnPhoto: returnPhoto ?? loan.returnPhoto,
      returnedOn: returnedOn ?? DateTime.now(),
    );
    await box.put(id, updated);
  }

  List<Loan> listOut() => box.values.where((l) => l.status == LoanStatus.out).toList();
  List<Loan> listOverdue(DateTime now) => box.values.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList();
}

class StashRepo {
  final Box<Stash> box;
  StashRepo(this.box);

  Future<void> add(Stash stash) async {
    await box.put(stash.id, stash);
  }

  Future<void> markFound(String id, {DateTime? lastChecked}) async {
    final stash = box.get(id);
    if (stash == null) return;
    final updated = Stash(
      id: stash.id,
      itemId: stash.itemId,
      placeName: stash.placeName,
      placeHint: stash.placeHint,
      photo: stash.photo,
      storedOn: stash.storedOn,
      lastChecked: lastChecked ?? DateTime.now(),
    );
    await box.put(id, updated);
  }

  List<Stash> listRecent([int count = 10]) {
    final sorted = box.values.toList()
      ..sort((a, b) => (b.lastChecked ?? b.storedOn).compareTo(a.lastChecked ?? a.storedOn));
    return sorted.take(count).toList();
  }
}
