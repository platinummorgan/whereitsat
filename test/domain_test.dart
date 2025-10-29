import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:who_has_it/domain/item.dart';
import 'package:who_has_it/domain/loan.dart';
import 'package:who_has_it/domain/stash.dart';
import 'package:uuid/uuid.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(LoanStatusAdapter());
  Hive.registerAdapter(LoanAdapter());
  Hive.registerAdapter(StashAdapter());

  group('Hive model persistence', () {
    test('Item persist/read', () async {
      var box = await Hive.openBox<Item>('test_items');
      final item = Item(
        id: Uuid().v4(),
        name: 'Test Item',
        category: 'Book',
        photos: ['photo1.jpg'],
        tags: ['tag1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await box.put(item.id, item);
      final read = box.get(item.id);
      expect(read?.name, 'Test Item');
      await box.deleteFromDisk();
    });
    test('Loan persist/read', () async {
      var box = await Hive.openBox<Loan>('test_loans');
      final loan = Loan(
        id: Uuid().v4(),
        itemId: 'item1',
        person: 'Alice',
        contact: 'alice@example.com',
        lentOn: DateTime.now(),
        dueOn: DateTime.now().add(Duration(days: 7)),
        status: LoanStatus.out,
        notes: 'Handle with care',
        returnPhoto: null,
        returnedOn: null,
      );
      await box.put(loan.id, loan);
      final read = box.get(loan.id);
      expect(read?.person, 'Alice');
      await box.deleteFromDisk();
    });
    test('Stash persist/read', () async {
      var box = await Hive.openBox<Stash>('test_stashes');
      final stash = Stash(
        id: Uuid().v4(),
        itemId: 'item1',
        placeName: 'Garage',
        placeHint: 'Shelf 2',
        photo: 'garage.jpg',
        storedOn: DateTime.now(),
        lastChecked: null,
      );
      await box.put(stash.id, stash);
      final read = box.get(stash.id);
      expect(read?.placeName, 'Garage');
      await box.deleteFromDisk();
    });
  });
}
