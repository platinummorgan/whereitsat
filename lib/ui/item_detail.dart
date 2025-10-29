import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import '../data/providers.dart';
import 'package:image_picker/image_picker.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({Key? key, required this.itemId}) : super(key: key);
  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  File? _returnPhoto;
  bool _markingReturned = false;
  bool _markingFound = false;

  Future<void> _pickReturnPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _returnPhoto = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final itemRepo = ref.watch(itemRepoProvider);
    final loanRepo = ref.watch(loanRepoProvider);
    final stashRepo = ref.watch(stashRepoProvider);
    final item = itemRepo.get(widget.itemId);
    final loans = loanRepo.box.values.where((l) => l.itemId == widget.itemId).toList();
    final stashes = stashRepo.box.values.where((s) => s.itemId == widget.itemId).toList();
    if (item == null) return const Scaffold(body: Center(child: Text('Item not found')));
    final activeLoan = loans.where((l) => l.status == LoanStatus.out).isNotEmpty ? loans.where((l) => l.status == LoanStatus.out).last : null;
    final activeStash = stashes.isNotEmpty ? stashes.last : null;
    return Scaffold(
      appBar: AppBar(title: Text(item.name), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () {/* TODO: Edit item */}),
        IconButton(icon: const Icon(Icons.assignment), onPressed: () {/* TODO: New loan */}),
        IconButton(icon: const Icon(Icons.inventory_2), onPressed: () {/* TODO: New stash */}),
        IconButton(icon: const Icon(Icons.share), onPressed: () {/* TODO: Share/Export */}),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPhotoCarousel(item.photos),
          const SizedBox(height: 16),
          _buildHeader(item),
          const SizedBox(height: 16),
          _buildTimeline(loans, stashes),
          const SizedBox(height: 24),
          if (activeLoan != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Mark Returned'),
              onPressed: _markingReturned ? null : () async {
                setState(() => _markingReturned = true);
                String? photoUri;
                if (_returnPhoto != null) photoUri = _returnPhoto!.uri.toString();
                await loanRepo.markReturned(activeLoan.id, returnPhoto: photoUri, returnedOn: DateTime.now());
                setState(() => _markingReturned = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as returned')));
              },
            ),
          if (activeStash != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark Found'),
              onPressed: _markingFound ? null : () async {
                setState(() => _markingFound = true);
                await stashRepo.markFound(activeStash.id, lastChecked: DateTime.now());
                setState(() => _markingFound = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as found')));
              },
            ),
          if (activeLoan != null)
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Add Return Photo'),
              onPressed: _pickReturnPhoto,
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(List<String> photoUris) {
    if (photoUris.isEmpty) {
      return const Center(child: Icon(Icons.photo, size: 64, color: Colors.grey));
    }
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photoUris.length,
        itemBuilder: (ctx, i) {
          final file = File(Uri.parse(photoUris[i]).path);
          return GestureDetector(
            onTap: () => _showFullscreenPhoto(ctx, file),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  void _showFullscreenPhoto(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.file(file),
        ),
      ),
    );
  }

  Widget _buildHeader(Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (item.category != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(item.category!, style: const TextStyle(color: Colors.grey)),
          ),
        Wrap(
          spacing: 8,
          children: item.tags.map((t) => Chip(label: Text(t))).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeline(List<Loan> loans, List<Stash> stashes) {
    final events = <_TimelineEvent>[];
    for (var l in loans) {
      events.add(_TimelineEvent('Loan created', l.lentOn, Icons.assignment));
      if (l.dueOn != null) events.add(_TimelineEvent('Due', l.dueOn!, Icons.schedule));
      if (l.status == LoanStatus.returned && l.returnedOn != null) events.add(_TimelineEvent('Returned', l.returnedOn!, Icons.assignment_turned_in));
    }
    for (var s in stashes) {
      events.add(_TimelineEvent('Stashed', s.storedOn, Icons.inventory_2));
      if (s.lastChecked != null) events.add(_TimelineEvent('Checked', s.lastChecked!, Icons.check_circle));
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
        ...events.map((e) => ListTile(
          leading: Icon(e.icon),
          title: Text(e.label),
          subtitle: Text(_formatDate(e.time)),
        )),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TimelineEvent {
  final String label;
  final DateTime time;
  final IconData icon;
  _TimelineEvent(this.label, this.time, this.icon);
}
