import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive/hive.dart';

import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

import 'box_like.dart';        // <— add
import 'hive_box_like.dart';   // <— add

export 'box_like.dart';        // <— critical: makes BoxLike visible to UI
export 'box_like.dart';

final itemBoxProvider = Provider<BoxLike<Item>>((ref) {
  final box = Hive.box<Item>('items');   // or ref.read(itemRepoProvider).box
  return HiveBoxLike<Item>(box);
});

final loanBoxProvider = Provider<BoxLike<Loan>>((ref) {
  final box = Hive.box<Loan>('loans');   // or ref.read(loanRepoProvider).box
  return HiveBoxLike<Loan>(box);
});

final stashBoxProvider = Provider<BoxLike<Stash>>((ref) {
  final box = Hive.box<Stash>('stashes'); // or ref.read(stashRepoProvider).box
  return HiveBoxLike<Stash>(box);
});
