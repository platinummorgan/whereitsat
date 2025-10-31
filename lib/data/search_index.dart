import 'package:hooks_riverpod/hooks_riverpod.dart';
// ...existing code...
import 'providers.dart';

class SearchResult {
  final String type; // 'loan' or 'stash'
  final String id;
  final String itemId;
  final String display;
  final List<String> highlights;
  SearchResult({required this.type, required this.id, required this.itemId, required this.display, required this.highlights});
}

class SearchIndex extends StateNotifier<List<SearchResult>> {
  final Ref ref;
  SearchIndex(this.ref) : super([]);

  void updateIndex() {
    final items = ref.read(itemBoxProvider).values.toList();
    final loans = ref.read(loanBoxProvider).values.toList();
    final stashes = ref.read(stashBoxProvider).values.toList();
    final List<SearchResult> results = [];
    for (final loan in loans) {
      final item = items.where((i) => i.id == loan.itemId).toList();
      if (item.isEmpty) continue;
      final it = item.first;
      results.add(SearchResult(
        type: 'loan',
        id: loan.id,
        itemId: it.id,
        display: '${it.name} (${loan.person})',
        highlights: [it.name, loan.person],
      ));
    }
    for (final stash in stashes) {
      final item = items.where((i) => i.id == stash.itemId).toList();
      if (item.isEmpty) continue;
      final it = item.first;
      results.add(SearchResult(
        type: 'stash',
        id: stash.id,
        itemId: it.id,
        display: '${it.name} (${stash.placeName}${stash.placeHint != null ? ', ${stash.placeHint!}' : ''})',
        highlights: [it.name, stash.placeName, if (stash.placeHint != null) stash.placeHint!],
      ));
    }
    state = results;
  }

  List<SearchResult> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return state.where((r) => r.highlights.any((h) => h.toLowerCase().contains(q))).toList();
  }
}

final searchIndexProvider = StateNotifierProvider<SearchIndex, List<SearchResult>>((ref) {
  final index = SearchIndex(ref);
  index.updateIndex();
  return index;
});