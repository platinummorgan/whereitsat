import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/providers.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;
  String _loanFilter = 'All';
  String _loanSearch = '';
  String _stashSearch = '';
  final _loanSearchController = TextEditingController();
  final _stashSearchController = TextEditingController();

  @override
  void dispose() {
    _loanSearchController.dispose();
    _stashSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who Has It')),
      body: Column(
        children: [
          TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [Tab(text: 'Loans'), Tab(text: 'Stashes')],
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildLoansTab(context),
                _buildStashesTab(context),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildLoansTab(BuildContext context) {
    final repo = ref.watch(loanRepoProvider);
    final itemRepo = ref.watch(itemRepoProvider);
    final now = ref.watch(clockProvider).now();
    final allLoans = repo.box.values.toList();
    final filtered = _filterLoans(allLoans, _loanFilter, _loanSearch, now);
    final overdue = filtered.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList();
    final out = filtered.where((l) => l.status == LoanStatus.out && (l.dueOn == null || l.dueOn!.isAfter(now))).toList();
    final returned = filtered.where((l) => l.status == LoanStatus.returned).toList();
    return Column(
      children: [
        _buildLoanFilterChips(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _loanSearchController,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search loans...'),
            onChanged: (v) => setState(() => _loanSearch = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (overdue.isNotEmpty) _buildLoanSection('Overdue', overdue, itemRepo),
              _buildLoanSection('Out', out, itemRepo),
              ExpansionTile(
                title: const Text('Returned'),
                initiallyExpanded: false,
                children: [_buildLoanSection('', returned, itemRepo)],
              ),
              if (filtered.isEmpty) _emptyState(Icons.assignment_late, 'No loans found'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanFilterChips() {
    final filters = ['All', 'Overdue', 'Out', 'Returned'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: filters.map((f) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(f),
          selected: _loanFilter == f,
          onSelected: (_) => setState(() => _loanFilter = f),
        ),
      )).toList(),
    );
  }

  List<Loan> _filterLoans(List<Loan> loans, String filter, String search, DateTime now) {
    var filtered = loans;
    if (filter == 'Overdue') {
      filtered = loans.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList();
    } else if (filter == 'Out') {
      filtered = loans.where((l) => l.status == LoanStatus.out).toList();
    } else if (filter == 'Returned') {
      filtered = loans.where((l) => l.status == LoanStatus.returned).toList();
    }
    if (search.isNotEmpty) {
      filtered = filtered.where((l) => l.person.toLowerCase().contains(search.toLowerCase()) || l.itemId.toLowerCase().contains(search.toLowerCase())).toList();
    }
    return filtered;
  }

  Widget _buildLoanSection(String title, List<Loan> loans, itemRepo) {
    if (loans.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...loans.map((loan) {
          final item = itemRepo.get(loan.itemId);
          return ListTile(
            title: Text(item?.name ?? 'Unknown'),
            subtitle: Text('${loan.person} • ${_formatDate(loan.lentOn)} → ${loan.dueOn != null ? _formatDate(loan.dueOn!) : 'No due'}'),
            trailing: _loanStatusBadge(loan.status),
            onTap: () {/* TODO: Navigate to ItemDetail */},
          );
        }).toList(),
      ],
    );
  }

  Widget _loanStatusBadge(LoanStatus status) {
    final color = status == LoanStatus.out ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(status.name, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStashesTab(BuildContext context) {
    final repo = ref.watch(stashRepoProvider);
    final itemRepo = ref.watch(itemRepoProvider);
    final stashes = repo.box.values.toList();
    final places = _groupStashesByPlace(stashes, _stashSearch);
    final quickPlaces = ['Closet', 'Garage', 'Bedside', 'Car', 'Office'];
    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: quickPlaces.map((p) => ActionChip(
            label: Text(p),
            onPressed: () => setState(() => _stashSearch = p),
          )).toList(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _stashSearchController,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search stashes...'),
            onChanged: (v) => setState(() => _stashSearch = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ...places.entries.map((e) => _buildStashSection(e.key, e.value, itemRepo)),
              if (stashes.isEmpty) _emptyState(Icons.inventory_2, 'No stashes found'),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<Stash>> _groupStashesByPlace(List<Stash> stashes, String search) {
    final filtered = search.isEmpty ? stashes : stashes.where((s) => s.placeName.toLowerCase().contains(search.toLowerCase())).toList();
    final map = <String, List<Stash>>{};
    for (var s in filtered) {
      map.putIfAbsent(s.placeName, () => []).add(s);
    }
    // Sort by most recent
    for (var v in map.values) {
      v.sort((a, b) => (b.lastChecked ?? b.storedOn).compareTo(a.lastChecked ?? a.storedOn));
    }
    return map;
  }

  Widget _buildStashSection(String place, List<Stash> stashes, itemRepo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(place, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...stashes.map((stash) {
          final item = itemRepo.get(stash.itemId);
          return ListTile(
            title: Text(item?.name ?? 'Unknown'),
            subtitle: Text('${stash.placeName} • ${_formatDate(stash.storedOn)}'),
            onTap: () {/* TODO: Navigate to ItemDetail */},
          );
        }).toList(),
      ],
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showFabModal(context),
      label: const Text('Add'),
      icon: const Icon(Icons.add),
    );
  }

  void _showFabModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.assignment),
              label: const Text('New Loan'),
              onPressed: () {/* TODO: New Loan */},
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2),
              label: const Text('New Stash'),
              onPressed: () {/* TODO: New Stash */},
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: const Text('New Item'),
                onPressed: () {/* TODO: New Item */},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
