// lib/ui/item_detail.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import '../data/providers.dart';
import '../data/notifications.dart';
import '../data/export.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  File? _returnPhoto;
  bool _markingReturned = false;
  bool _markingFound = false;

  Future<void> _exportSingleItem(BuildContext context, Item item) async {
    try {
      final loanBox = ref.read(loanBoxProvider);
      final stashBox = ref.read(stashBoxProvider);
      final loans = loanBox.values.where((l) => l.itemId == item.id).toList();
      final stashes = stashBox.values.where((s) => s.itemId == item.id).toList();

      // Uses export.dart (writes to temp dir and returns File handles)
      final csvFile = await exportItemsCsv([item], loans, stashes);
      final pdfFile = await exportSummaryPdf(items: [item], loans: loans, stashes: stashes);

      await Share.shareXFiles(
        [
          XFile(csvFile.path, mimeType: 'text/csv'),
          XFile(pdfFile.path, mimeType: 'application/pdf'),
        ],
        text: 'Exported item: ${item.name}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export successful')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _pickReturnPhoto({ImageSource source = ImageSource.camera}) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;
      setState(() => _returnPhoto = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to capture/select photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemBox = ref.watch(itemBoxProvider);
    final loanBox = ref.watch(loanBoxProvider);
    final stashBox = ref.watch(stashBoxProvider);

    final item = itemBox.get(widget.itemId);
    if (item == null) {
      return const Scaffold(body: Center(child: Text('Item not found')));
    }

    final loans = loanBox.values
        .where((l) => l.itemId == widget.itemId)
        .toList()
      ..sort((a, b) => a.lentOn.compareTo(b.lentOn)); // chronological

    final stashes = stashBox.values
        .where((s) => s.itemId == widget.itemId)
        .toList()
      ..sort((a, b) => a.storedOn.compareTo(b.storedOn)); // chronological

    final activeLoan = loans
        .where((l) => l.status == LoanStatus.out)
        .toList()
      ..sort((a, b) => b.lentOn.compareTo(a.lentOn));
    final Loan? currentLoan = activeLoan.isNotEmpty ? activeLoan.first : null;

    final loansByRecency = [...loans]
      ..sort((a, b) => (b.returnedOn ?? b.lentOn).compareTo(a.returnedOn ?? a.lentOn));
    final Loan? latestLoan = loansByRecency.isNotEmpty ? loansByRecency.first : null;

    final activeStashes = stashes
        .where((s) => s.returnedOn == null)
        .toList()
      ..sort((a, b) {
        final aKey = a.lastChecked ?? a.storedOn;
        final bKey = b.lastChecked ?? b.storedOn;
        return bKey.compareTo(aKey);
      });
    final Stash? currentStash = activeStashes.isNotEmpty ? activeStashes.first : null;

    final stashesByRecency = [...stashes]
      ..sort((a, b) {
        final aKey = a.returnedOn ?? a.lastChecked ?? a.storedOn;
        final bKey = b.returnedOn ?? b.lastChecked ?? b.storedOn;
        return bKey.compareTo(aKey);
      });
    final Stash? latestStash = stashesByRecency.isNotEmpty ? stashesByRecency.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export',
            onPressed: () => _exportSingleItem(context, item),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPhotoCarousel(item.photos),
            const SizedBox(height: 16),
            _buildHeader(item),
            const SizedBox(height: 16),
            _buildStatusRow(latestLoan, latestStash),
            const SizedBox(height: 16),
            _buildTimeline(loans, stashes),
            const SizedBox(height: 24),

            if (currentLoan != null)
              FilledButton.icon(
                icon: const Icon(Icons.assignment_turned_in),
                label: Text(_markingReturned ? 'Marking…' : 'Mark Returned'),
                onPressed: _markingReturned
                    ? null
                    : () async {
                        setState(() => _markingReturned = true);
                        final now = DateTime.now();
                        String? photoUri;
                        if (_returnPhoto != null) photoUri = _returnPhoto!.uri.toString();
                        await loanBox.put(
                          currentLoan.id,
                          Loan(
                            id: currentLoan.id,
                            itemId: currentLoan.itemId,
                            person: currentLoan.person,
                            contact: currentLoan.contact,
                            lentOn: currentLoan.lentOn,
                            dueOn: currentLoan.dueOn,
                            status: LoanStatus.returned,
                            notes: currentLoan.notes,
                            returnPhoto: photoUri,
                            returnedOn: now,
                            where: currentLoan.where,
                            category: currentLoan.category,
                          ),
                        );
                        await cancelLoanNotification(currentLoan.id);
                        if (currentStash != null) {
                          await stashBox.put(
                            currentStash.id,
                            Stash(
                              id: currentStash.id,
                              itemId: currentStash.itemId,
                              placeName: currentStash.placeName,
                              placeHint: currentStash.placeHint,
                              photo: currentStash.photo,
                              storedOn: currentStash.storedOn,
                              lastChecked: now,
                              returnedOn: currentStash.returnedOn ?? now,
                            ),
                          );
                        }

                        setState(() {
                          _markingReturned = false;
                          _returnPhoto = null;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as returned (stash updated)')),
                        );
                      },
              ),

            if (currentStash != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: Text(_markingFound ? 'Marking…' : 'Mark Found'),
                onPressed: _markingFound
                    ? null
                    : () async {
                        setState(() => _markingFound = true);
                        final now = DateTime.now();
                        await stashBox.put(
                          currentStash.id,
                          Stash(
                            id: currentStash.id,
                            itemId: currentStash.itemId,
                            placeName: currentStash.placeName,
                            placeHint: currentStash.placeHint,
                            photo: currentStash.photo,
                            storedOn: currentStash.storedOn,
                            lastChecked: now,
                            returnedOn: now,
                          ),
                        );
                        setState(() => _markingFound = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as found')),
                        );
                      },
              ),
            ],

            if (currentLoan != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Add Return Photo'),
                    onPressed: () => _pickReturnPhoto(source: ImageSource.camera),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                    onPressed: () => _pickReturnPhoto(source: ImageSource.gallery),
                  ),
                ],
              ),
              if (_returnPhoto != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_returnPhoto!, width: 120, height: 120, fit: BoxFit.cover),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- UI helpers ----

  Widget _buildHeader(Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (item.category != null && item.category!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(item.category!, style: const TextStyle(color: Colors.grey)),
          ),
        if (item.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: item.tags.map((t) => Chip(label: Text(t))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusRow(Loan? loan, Stash? stash) {
    final children = <Widget>[];

    if (loan != null) {
      if (loan.status == LoanStatus.out) {
        children.add(_pill('On loan to ${loan.person}', Colors.deepPurple));
        if (loan.dueOn != null) {
          children.add(_pill('Due ${_fmtDateTime(loan.dueOn!)}', Colors.orange));
        }
      } else {
        final returnedLabel = loan.returnedOn != null
            ? 'Returned ${_fmtDateTime(loan.returnedOn!)}'
            : 'Returned';
        children.add(_pill(returnedLabel, Colors.green));
      }
    }

    if (stash != null) {
      if (stash.returnedOn != null) {
        children.add(_pill('Found ${_fmtDateTime(stash.returnedOn!)}', Colors.teal));
      } else {
        children.add(_pill('Stashed @ ${stash.placeName}', Colors.green));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  final DateFormat _dateTimeFmt = DateFormat('MMM d, h:mm a'); // e.g., Oct 30, 5:07 PM
  final DateFormat _dateFmt = DateFormat('MMM d, yyyy');       // e.g., Oct 30, 2025

  String _fmtDateTime(DateTime dt) => _dateTimeFmt.format(dt);
  String _fmtDate(DateTime dt) => _dateFmt.format(dt);

  Widget _buildPhotoCarousel(List<String> uris) {
    if (uris.isEmpty) {
      return const Center(child: Icon(Icons.photo, size: 64, color: Colors.grey));
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: uris.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final provider = _imageProviderFromUri(uris[i]);
          return GestureDetector(
            onTap: () => _showFullscreen(ctx, provider),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: provider,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 110, height: 110, child: ColoredBox(color: Colors.black12)),
              ),
            ),
          );
        },
      ),
    );
  }

  ImageProvider _imageProviderFromUri(String uri) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return NetworkImage(uri);
    }
    if (uri.startsWith('file://')) {
      return FileImage(File(Uri.parse(uri).toFilePath()));
    }
    if (uri.startsWith('/')) {
      return FileImage(File(uri));
    }
    try {
      final parsed = Uri.parse(uri);
      if (parsed.scheme == 'file') {
        return FileImage(File(parsed.toFilePath()));
      }
    } catch (_) {}
    return const AssetImage('assets/transparent.png');
  }

  void _showFullscreen(BuildContext context, ImageProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image(image: provider, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<Loan> loans, List<Stash> stashes) {
    final events = <_TimelineEvent>[];
    for (final l in loans) {
      events.add(_TimelineEvent('Loaned to ${l.person}', l.lentOn, Icons.assignment));
      if (l.dueOn != null) events.add(_TimelineEvent('Due', l.dueOn!, Icons.schedule));
      if (l.status == LoanStatus.returned && l.returnedOn != null) {
        events.add(_TimelineEvent('Returned', l.returnedOn!, Icons.assignment_turned_in));
      }
    }
    for (final s in stashes) {
      events.add(_TimelineEvent('Stashed @ ${s.placeName}', s.storedOn, Icons.inventory_2));
      if (s.returnedOn != null) {
        events.add(_TimelineEvent('Found', s.returnedOn!, Icons.check_circle));
      }
      if (s.lastChecked != null) events.add(_TimelineEvent('Checked', s.lastChecked!, Icons.check_circle));
    }

    events.sort((a, b) => b.time.compareTo(a.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No events yet'),
          )
        else
          ...events.map(
            (e) => ListTile(
              dense: true,
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: Text(_fmtDate(e.time)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

class _TimelineEvent {
  final String label;
  final DateTime time;
  final IconData icon;
  _TimelineEvent(this.label, this.time, this.icon);
}
