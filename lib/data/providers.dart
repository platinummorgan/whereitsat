import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive/hive.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import 'repos.dart';

final itemBoxProvider = Provider<Box<Item>>((ref) => Hive.box<Item>('items'));
final loanBoxProvider = Provider<Box<Loan>>((ref) => Hive.box<Loan>('loans'));
final stashBoxProvider = Provider<Box<Stash>>((ref) => Hive.box<Stash>('stashes'));

final itemRepoProvider = Provider<ItemRepo>((ref) => ItemRepo(ref.watch(itemBoxProvider)));
final loanRepoProvider = Provider<LoanRepo>((ref) => LoanRepo(ref.watch(loanBoxProvider)));
final stashRepoProvider = Provider<StashRepo>((ref) => StashRepo(ref.watch(stashBoxProvider)));

class Clock {
  DateTime now() => DateTime.now();
}
final clockProvider = Provider<Clock>((ref) => Clock());
