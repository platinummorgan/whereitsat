import 'package:hive_flutter/hive_flutter.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

Future<void> initDb() async {
  print('Initializing Hive...');
  await Hive.initFlutter();
  print('Registering adapters...');
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(LoanStatusAdapter());
  Hive.registerAdapter(LoanAdapter());
  Hive.registerAdapter(StashAdapter());
  print('Opening items box...');
  final itemsBox = await Hive.openBox<Item>('items');
  print('Opening loans box...');
  final loansBox = await Hive.openBox<Loan>('loans');
  print('Opening stashes box...');
  final stashesBox = await Hive.openBox<Stash>('stashes');
  print('Opening settings box...');
  await Hive.openBox('settings');

  // TEMP: Clear all boxes to fix adapter mismatch
  print('Clearing items box...');
  await itemsBox.clear();
  print('Clearing loans box...');
  await loansBox.clear();
  print('Clearing stashes box...');
  await stashesBox.clear();
  print('Hive initialization complete.');
}
