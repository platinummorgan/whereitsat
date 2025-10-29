import 'package:hive_flutter/hive_flutter.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

Future<void> initDb() async {
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(LoanStatusAdapter());
  Hive.registerAdapter(LoanAdapter());
  Hive.registerAdapter(StashAdapter());
  await Hive.openBox<Item>('items');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Stash>('stashes');
  await Hive.openBox('settings');
}
