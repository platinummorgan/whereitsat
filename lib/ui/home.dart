// lib/ui/home.dart

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import 'widgets/empty_state.dart'; // EmptyState, kFilterRowHeight
import '../data/providers.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import '../data/box_like.dart';           // <-- REQUIRED for BoxLike<T>
import 'add_loan.dart';
import 'new_stash.dart';
import 'item_detail.dart';
import 'img.dart'; // buildItemImage

bool _isAfterNullable(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.isAfter(b);
}

class _SearchResult {
  final String type; // 'loan' or 'stash'
  final String itemId;
  final String highlightField;
  _SearchResult({
    required this.type,
    required this.itemId,
    required this.highlightField,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final DateFormat _dateTimeFmt = DateFormat('MMM d, h:mm a'); // Oct 30, 5:07 PM
  String _fmtDateTime(DateTime dt) => _dateTimeFmt.format(dt);

  // Tabs: 0 = Loans, 1 = Stashes
  int _selectedTab = 0;

  // Stash filter state
  String? _selectedPlace;

  // Loan filter state: 0=All, 1=Overdue, 2=Out, 3=Returned
  int _loanFilter = 0;
  final bool _showReturned = false;

  // Search
  String _searchQuery = '';
  List<_SearchResult> _searchResults = [];
  DateTime _lastSearch = DateTime.now();

  Future<void> _exportData(BuildContext context) async {
    final itemBox = ref.read(itemBoxProvider);
    final loanBox = ref.read(loanBoxProvider);
    final stashBox = ref.read(stashBoxProvider);
    final items = itemBox.values.toList();
    final loans = loanBox.values.toList();
    final stashes = stashBox.values.toList();
    try {
      // build latest maps
      final latestLoanByItem = <String, Loan>{};
      for (final l in loans) {
        final curr = latestLoanByItem[l.itemId];
        final lKey = l.returnedOn ?? l.lentOn;
        final currKey = curr?.returnedOn ?? curr?.lentOn;
        if (curr == null || _isAfterNullable(lKey, currKey)) {
          latestLoanByItem[l.itemId] = l;
        }
      }
      final latestStashByItem = <String, Stash>{};
      for (final s in stashes) {
        final curr = latestStashByItem[s.itemId];
        final sKey = s.returnedOn ?? s.lastChecked ?? s.storedOn;
        final currKey = curr?.returnedOn ?? curr?.lastChecked ?? curr?.storedOn;
        if (curr == null || _isAfterNullable(sKey, currKey)) {
          latestStashByItem[s.itemId] = s;
        }
      }

      final rows = <List<String>>[
        ['Item Name', 'Category', 'Tags', 'Status', 'Person', 'Due', 'Place', 'Hint'],
      ];
      for (final item in items) {
        final latestLoan = latestLoanByItem[item.id];
        final latestStash = latestStashByItem[item.id];
        final status = () {
          if (latestLoan != null) return latestLoan.status == LoanStatus.out ? 'Out' : 'Returned';
          if (latestStash != null) return 'Stashed';
          return 'None';
        }();
        rows.add([
          item.name,
          item.category ?? '',
          item.tags.join(','),
          status,
          latestLoan?.person ?? '',
          latestLoan?.dueOn == null ? '' : _fmtDateTime(latestLoan!.dueOn!),
          latestStash?.placeName ?? '',
          latestStash?.placeHint ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      final fileBytes = Uint8List.fromList(csv.codeUnits);
      final result = await FileSaver.instance.saveFile(
        name: 'where_its_at_items',
        bytes: fileBytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (result.isNotEmpty) {
        try {
          await Share.shareXFiles([
            XFile(result, mimeType: 'text/csv'),
          ], text: 'Exported items CSV');
        } catch (e) {
          debugPrint('Share error: $e');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported! You can now share or open the file.')),
      );
    } catch (e, st) {
      debugPrint('Export error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _lastSearch = DateTime.now();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (DateTime.now().difference(_lastSearch) >= const Duration(milliseconds: 250)) {
        _runSearch();
      }
    });
  }

  void _runSearch() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final itemBox = ref.read(itemBoxProvider);
    final loanBox = ref.read(loanBoxProvider);
    final stashBox = ref.read(stashBoxProvider);
    final loans = loanBox.values.toList();
    final stashes = stashBox.values.toList();

    final results = <_SearchResult>[];

    for (final loan in loans) {
      final item = itemBox.get(loan.itemId);
      final fields = <String>[
        if (item?.name != null) item!.name,
        ...(item?.tags ?? const <String>[]),
        loan.person,
      ];
      if (fields.any((f) => f.toLowerCase().contains(query))) {
        results.add(_SearchResult(type: 'loan', itemId: loan.itemId, highlightField: item?.name ?? loan.person));
      }
    }

    for (final stash in stashes) {
      final item = itemBox.get(stash.itemId);
      final fields = <String>[
        if (item?.name != null) item!.name,
        ...(item?.tags ?? const <String>[]),
        stash.placeName,
        if (stash.placeHint != null) stash.placeHint!,
      ];
      if (fields.any((f) => f.toLowerCase().contains(query))) {
        results.add(_SearchResult(type: 'stash', itemId: stash.itemId, highlightField: item?.name ?? stash.placeName));
      }
    }

    setState(() => _searchResults = results);
  }

  bool get _showSearch => _searchQuery.trim().isNotEmpty;

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Widget _highlight(String text, String query) {
    if (query.isEmpty) return Text(text);
    final q = query.toLowerCase();
    final t = text.toLowerCase();
    final i = t.indexOf(q);
    if (i < 0) return Text(text);

    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final j = i + q.length;

    final highlightBg = theme.colorScheme.secondaryContainer;
    final highlightFg = theme.colorScheme.onSecondaryContainer;

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, j),
            style: base.copyWith(backgroundColor: highlightBg, color: highlightFg, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(j)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemBox = ref.watch(itemBoxProvider);
    final loanBox = ref.watch(loanBoxProvider);
    final stashBox = ref.watch(stashBoxProvider);
    final loans = loanBox.values.toList();
    final stashes = stashBox.values.toList();

    final today = DateTime.now();
    final todayFloor = DateTime(today.year, today.month, today.day);
    final overdueCount = loans.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(todayFloor)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Where It’s At'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export',
            onPressed: () => _exportData(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(144),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Material(
                  elevation: _showSearch ? 2 : 0,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 54,
                    child: TextField(
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search items, loans, stashes…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: Row(
                            children: [
                              const Text('Loans'),
                              if (overdueCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                  child: Text('$overdueCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                        const ButtonSegment(value: 1, label: Text('Stashes')),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (s) => setState(() => _selectedTab = s.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                        side: WidgetStateProperty.all(
                          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: kFilterRowHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: (_selectedTab == 0)
                      ? Padding(
                          key: const ValueKey('loan-filters'),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(label: const Text('All'), selected: _loanFilter == 0, onSelected: (_) => setState(() => _loanFilter = 0)),
                              ChoiceChip(label: const Text('Overdue'), selected: _loanFilter == 1, onSelected: (_) => setState(() => _loanFilter = 1)),
                              ChoiceChip(label: const Text('Out'), selected: _loanFilter == 2, onSelected: (_) => setState(() => _loanFilter = 2)),
                              ChoiceChip(label: const Text('Returned'), selected: _loanFilter == 3, onSelected: (_) => setState(() => _loanFilter = 3)),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('stash-spacer')),
                ),
              ),
            ],
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: _showSearch
                ? _buildSearchResults(context, itemBox)
                : (_selectedTab == 0
                    ? _buildLoansListFiltered(context, loans, itemBox)
                    : _buildStashesListFiltered(context, stashes, itemBox)),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.assignment),
                    title: const Text('Add Loan'),
                    onTap: () => Navigator.of(ctx).pop('loan'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('Add Stash'),
                    onTap: () => Navigator.of(ctx).pop('stash'),
                  ),
                ],
              ),
            ),
          );
          if (!mounted) return;
          if (result == 'loan') {
            final loan = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddLoanSheet()));
            if (loan != null && mounted) setState(() {}); // triggers rebuild
          } else if (result == 'stash') {
            final stash = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewStashScreen()));
            if (stash != null && mounted) setState(() {}); // triggers rebuild
          }
        },
      ),
    );
  }

  // ---------------- Search UI ----------------
  Widget _buildSearchResults(BuildContext context, BoxLike<Item> itemBox) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (_searchResults.any((r) => r.type == 'loan'))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Loans', style: Theme.of(context).textTheme.titleMedium),
          ),
        ..._searchResults.where((r) => r.type == 'loan').map(
              (r) => Card(
                child: ListTile(
                  title: _highlight(itemBox.get(r.itemId)?.name ?? r.highlightField, _searchQuery),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: r.itemId))),
                ),
              ),
            ),
        if (_searchResults.any((r) => r.type == 'stash'))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Stashes', style: Theme.of(context).textTheme.titleMedium),
          ),
        ..._searchResults.where((r) => r.type == 'stash').map(
              (r) => Card(
                child: ListTile(
                  title: _highlight(itemBox.get(r.itemId)?.name ?? r.highlightField, _searchQuery),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: r.itemId))),
                ),
              ),
            ),
        if (_searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No results found')),
          ),
      ],
    );
  }

  // ---------------- Stashes (filtered) ----------------
  Widget _buildStashesListFiltered(BuildContext context, List<Stash> stashes, BoxLike<Item> itemBox) {
    final sorted = [...stashes]
      ..sort((a, b) {
        final aDate = a.returnedOn ?? a.lastChecked ?? a.storedOn;
        final bDate = b.returnedOn ?? b.lastChecked ?? b.storedOn;
        return bDate.compareTo(aDate);
      });

    final uniquePlaces = <String>[];
    for (final s in sorted) {
      if (s.placeName.isNotEmpty && !uniquePlaces.contains(s.placeName)) {
        uniquePlaces.add(s.placeName);
        if (uniquePlaces.length >= 8) break;
      }
    }

    final returned = sorted.where((s) => s.returnedOn != null).toList();
    final active = sorted.where((s) => s.returnedOn == null).toList();
    final filteredActive = _selectedPlace == null ? active : active.where((s) => s.placeName == _selectedPlace).toList();
    final filteredReturned = _selectedPlace == null ? returned : returned.where((s) => s.placeName == _selectedPlace).toList();
    final filtered = [...filteredActive, ...filteredReturned];

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2,
        text: 'No stashes found for this filter.',
        ctaText: 'Add Stash',
        badgeColor: Colors.orange,
        onPressed: () async {
          final stash = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewStashScreen()));
          if (stash != null && mounted) setState(() {});
        },
      );
    }

    return Column(
      children: [
        if (uniquePlaces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: _selectedPlace == null, onSelected: (_) => setState(() => _selectedPlace = null)),
                ...uniquePlaces.map(
                  (place) => ChoiceChip(
                    label: Text(place),
                    selected: _selectedPlace == place,
                    onSelected: (v) => setState(() => _selectedPlace = v ? place : null),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              ...filtered.map((stash) {
                final item = itemBox.get(stash.itemId);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: stash.itemId)),
                      );
                      if (!mounted) return;
                      setState(() {});
                    },
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: item?.photos.isNotEmpty == true
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: buildItemImage(item!.photos.first, 40, 40))
                              : const Icon(Icons.inventory_2, size: 40),
                        ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item?.name ?? 'Unknown item', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(stash.placeName, style: const TextStyle(color: Colors.grey)),
                          if (stash.returnedOn == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Checked ${_timeAgo(stash.lastChecked ?? stash.storedOn)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          if (item?.category != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                              child: Text(item!.category!, style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (stash.returnedOn != null)
                          Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Found',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              )
                            else
                              const Text('Stash', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                    IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            final sBox = ref.read(stashBoxProvider);
                            await sBox.delete(stash.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stash deleted')));
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (returned.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      const Text('Found', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Loans (filtered) ----------------
  Widget _buildLoansListFiltered(BuildContext context, List<Loan> loans, BoxLike<Item> itemBox) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue = loans
        .where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(today))
        .toList()
      ..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));

    final out = loans
        .where((l) => l.status == LoanStatus.out && (l.dueOn == null || !l.dueOn!.isBefore(today)))
        .toList()
      ..sort((a, b) {
        final aDate = a.dueOn ?? a.lentOn;
        final bDate = b.dueOn ?? b.lentOn;
        return aDate.compareTo(bDate);
      });

    final returned = loans
        .where((l) => l.status == LoanStatus.returned)
        .toList()
      ..sort((a, b) => (b.returnedOn ?? b.lentOn).compareTo(a.returnedOn ?? a.lentOn));

    List<Loan> visible;
    switch (_loanFilter) {
      case 1:
        visible = overdue;
        break;
      case 2:
        visible = out;
        break;
      case 3:
        visible = returned;
        break;
      default:
        visible = [
          ...overdue,
          ...out,
          ...returned,
        ];
    }

    if (visible.isEmpty && (_loanFilter == 0 || _loanFilter == 1 || _loanFilter == 2)) {
      return EmptyState(
        icon: Icons.assignment,
        text: 'No loans found for this filter.',
        ctaText: 'Add Loan',
        badgeColor: Theme.of(context).colorScheme.primary,
        onPressed: () async {
          final loan = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddLoanSheet()));
          if (loan != null && mounted) setState(() {});
        },
      );
    }
    if (visible.isEmpty && _loanFilter == 3) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment, size: 36, color: Colors.deepPurple),
              SizedBox(height: 12),
              Text('No returned loans yet.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: visible.map((loan) {
        final item = itemBox.get(loan.itemId);
        final isOverdue = loan.status == LoanStatus.out && loan.dueOn != null && loan.dueOn!.isBefore(today);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: ListTile(
            leading: Padding(
              padding: const EdgeInsets.all(4.0),
              child: item?.photos.isNotEmpty == true
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: buildItemImage(item!.photos.first, 56, 56))
                  : const Icon(Icons.inventory_2, size: 56),
            ),
            title: Text(item?.name ?? 'Unknown item'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.person),
                if (loan.status == LoanStatus.returned && loan.returnedOn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Returned ${_fmtDateTime(loan.returnedOn!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  )
                else if (loan.dueOn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Due ${_fmtDateTime(loan.dueOn!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loan.status == LoanStatus.returned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Returned', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  const Text('Overdue', style: TextStyle(color: Colors.red)),
                ],
                if (loan.status != LoanStatus.returned && loan.dueOn != null) ...[
                  const SizedBox(width: 8),
                  Text('Due: ${_fmtDateTime(loan.dueOn!)}'),
                ],
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Delete Loan',
                  onPressed: () async {
                    final loanBox = ref.read(loanBoxProvider);
                    await loanBox.delete(loan.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan deleted')));
                    setState(() {});
                  },
                ),
              ],
            ),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: loan.itemId)));
              if (!mounted) return;
              setState(() {});
            },
          ),
        );
      }).toList(),
    );
  }
}
