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

final loanListProvider = StateNotifierProvider<LoanListNotifier, List<Loan>>((ref) {
  final repo = ref.watch(loanRepoProvider);
  return LoanListNotifier(repo);
});

class LoanListNotifier extends StateNotifier<List<Loan>> {
  final LoanRepo repo;
  LoanListNotifier(this.repo) : super(repo.listOut());
  void refresh() => state = repo.listOut();
  void filter(String filter, String search, DateTime now) {
    var loans = repo.box.values.toList();
    if (filter == 'Overdue') {
      loans = loans.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList();
    } else if (filter == 'Out') {
      loans = loans.where((l) => l.status == LoanStatus.out).toList();
    } else if (filter == 'Returned') {
      loans = loans.where((l) => l.status == LoanStatus.returned).toList();
    }
    if (search.isNotEmpty) {
      loans = loans.where((l) => l.person.toLowerCase().contains(search.toLowerCase()) || l.itemId.toLowerCase().contains(search.toLowerCase())).toList();
    }
    state = loans;
  }
}

final stashListProvider = StateNotifierProvider<StashListNotifier, List<Stash>>((ref) {
  final repo = ref.watch(stashRepoProvider);
  return StashListNotifier(repo);
});

class StashListNotifier extends StateNotifier<List<Stash>> {
  final StashRepo repo;
  StashListNotifier(this.repo) : super(repo.listRecent());
  void refresh() => state = repo.listRecent();
  void filter(String search) {
    var stashes = repo.box.values.toList();
    if (search.isNotEmpty) {
      stashes = stashes.where((s) => s.placeName.toLowerCase().contains(search.toLowerCase())).toList();
    }
    state = stashes;
  }
}
