// lib/data/export_bundle.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

/// Export a bundle JSON file for perfect round-trip import/export.
///
/// Schema:
/// {
///   "version": 1,
///   "exportedAt": "<ISO8601>",
///   "items":   [ ...full Item objects... ],
///   "loans":   [ ...full Loan objects... ],
///   "stashes": [ ...full Stash objects... ]
/// }
///
/// Throws UnsupportedError on web.
Future<File> exportBundleJson({
  required List<Item> items,
  required List<Loan> loans,
  required List<Stash> stashes,
  required String directoryPath,
}) async {
  if (kIsWeb) {
    throw UnsupportedError('File export is not supported on web.');
  }

  final now = DateTime.now().toUtc();

  Map<String, dynamic> toMap(dynamic obj) {
    if (obj is Item) {
      return {
        'id': obj.id,
        'name': obj.name,
        'category': obj.category,
        'tags': obj.tags,
        'photos': obj.photos,
        'createdAt': obj.createdAt.toIso8601String(),
        'updatedAt': obj.updatedAt.toIso8601String(),
      };
    } else if (obj is Loan) {
      return {
        'id': obj.id,
        'itemId': obj.itemId,
        'person': obj.person,
        'contact': obj.contact,
        'lentOn': obj.lentOn.toIso8601String(),
        'dueOn': obj.dueOn?.toIso8601String(),
        'status': obj.status.name,
        'notes': obj.notes,
        'returnPhoto': obj.returnPhoto,
        'returnedOn': obj.returnedOn?.toIso8601String(),
        'where': obj.where,
        'category': obj.category,
      };
    } else if (obj is Stash) {
      return {
        'id': obj.id,
        'itemId': obj.itemId,
        'placeName': obj.placeName,
        'placeHint': obj.placeHint,
        'photo': obj.photo,
        'storedOn': obj.storedOn.toIso8601String(),
        'lastChecked': obj.lastChecked?.toIso8601String(),
      };
    }
    throw ArgumentError('Unknown object type for bundle export');
  }

  final bundle = {
    'version': 1,
    'exportedAt': now.toIso8601String(),
    'items': items.map(toMap).toList(),
    'loans': loans.map(toMap).toList(),
    'stashes': stashes.map(toMap).toList(),
  };

  final jsonStr = jsonEncode(bundle);
  final file = File('$directoryPath/where_its_at_bundle.json');
  await file.writeAsString(jsonStr);
  return file;
}

/// Build a zip in memory from a set of lazily-produced files, then
/// deletes the temp files it created.
Future<Uint8List> buildExportArchiveWithSelection(
  Map<String, Future<File> Function()> filesToInclude,
) async {
  final archive = Archive();
  for (final entry in filesToInclude.entries) {
    final file = await entry.value();
    try {
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    } finally {
      await _tryDelete(file);
    }
  }
  final encoder = ZipEncoder();
  final data = encoder.encode(archive);
  return Uint8List.fromList(data);
}

// ----------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------

final _df = DateFormat('yyyy-MM-dd');

String _fmt(DateTime? dt) => dt == null ? '' : _df.format(dt);

/// Most recent event date for a loan (returnedOn falls back to lentOn).
DateTime _loanSortKey(Loan l) => l.returnedOn ?? l.lentOn;

/// Most recent event date for a stash (lastChecked falls back to storedOn).
DateTime _stashSortKey(Stash s) => s.returnedOn ?? s.lastChecked ?? s.storedOn;

/// Null-safe image loader for PDF thumbnails. Returns null if unreadable.
Uint8List? _tryLoadBytes(String pathOrUri) {
  try {
    return File(pathOrUri).readAsBytesSync();
  } catch (_) {
    return null;
  }
}

/// Temp folder we can write to, cross-platform (except web).
Future<Directory> _tempDir() async {
  if (kIsWeb) {
    throw UnsupportedError('File export is not supported on web.');
  }
  return getTemporaryDirectory();
}

// ----------------------------------------------------------------------
// CSV exports
// ----------------------------------------------------------------------

Future<File> exportItemsCsv(
  List<Item> items,
  List<Loan> loans,
  List<Stash> stashes,
) async {
  // Build quick lookups of latest loan/stash per item by date
  final latestLoanByItem = <String, Loan>{};
  for (final l in loans) {
    final curr = latestLoanByItem[l.itemId];
    if (curr == null || _loanSortKey(l).isAfter(_loanSortKey(curr))) {
      latestLoanByItem[l.itemId] = l;
    }
  }
  final latestStashByItem = <String, Stash>{};
  for (final s in stashes) {
    final curr = latestStashByItem[s.itemId];
    if (curr == null || _stashSortKey(s).isAfter(_stashSortKey(curr))) {
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
      if (latestLoan != null) {
        return latestLoan.status == LoanStatus.out ? 'Out' : 'Returned';
      }
      if (latestStash != null) return 'Stashed';
      return 'None';
    }();

    rows.add([
      item.name,
      item.category ?? '',
      item.tags.join(','),
      status,
      latestLoan?.person ?? '',
      _fmt(latestLoan?.dueOn),
      latestStash?.placeName ?? '',
      latestStash?.placeHint ?? '',
    ]);
  }

  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await _tempDir();
  final file =
      File('${dir.path}/where_its_at_items_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

Future<File> exportLoansCsv(List<Loan> loans) async {
  final sorted = [...loans]..sort((a, b) => _loanSortKey(b).compareTo(_loanSortKey(a)));
  final rows = <List<String>>[
    ['ItemId', 'Person', 'Contact', 'Lent On', 'Due On', 'Status', 'Returned On'],
  ];
  for (final loan in sorted) {
    rows.add([
      loan.itemId,
      loan.person,
      loan.contact ?? '',
      _fmt(loan.lentOn),
      _fmt(loan.dueOn),
      loan.status.name,
      _fmt(loan.returnedOn),
    ]);
  }
  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await _tempDir();
  final file =
      File('${dir.path}/where_its_at_loans_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

Future<File> exportStashesCsv(List<Stash> stashes) async {
  final sorted = [...stashes]..sort((a, b) => _stashSortKey(b).compareTo(_stashSortKey(a)));
  final rows = <List<String>>[
    ['ItemId', 'Place Name', 'Hint', 'Stored On', 'Last Checked'],
  ];
  for (final stash in sorted) {
    rows.add([
      stash.itemId,
      stash.placeName,
      stash.placeHint ?? '',
      _fmt(stash.storedOn),
      _fmt(stash.lastChecked),
    ]);
  }
  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await _tempDir();
  final file = File(
      '${dir.path}/where_its_at_stashes_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

// ----------------------------------------------------------------------
// PDF export
// ----------------------------------------------------------------------

Future<File> exportSummaryPdf({
  required List<Item> items,
  required List<Loan> loans,
  required List<Stash> stashes,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();

  // Item lookup for O(1) access in sections
  final itemById = {for (final i in items) i.id: i};

  // Split loans
  final overdue = loans
      .where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now))
      .toList()
    ..sort((a, b) => (a.dueOn ?? a.lentOn).compareTo(b.dueOn ?? b.lentOn));

  final active = loans
      .where((l) => l.status == LoanStatus.out && (l.dueOn == null || l.dueOn!.isAfter(now)))
      .toList()
    ..sort((a, b) => (a.dueOn ?? a.lentOn).compareTo(b.dueOn ?? b.lentOn));

  final stashesSorted =
      [...stashes]..sort((a, b) => _stashSortKey(b).compareTo(_stashSortKey(a)));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('Where It’s At – Summary (${_df.format(now)})'),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Overdue Loans',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        _buildLoanSection(overdue, itemById),
        pw.SizedBox(height: 12),
        pw.Text('Active Loans',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        _buildLoanSection(active, itemById),
        pw.SizedBox(height: 12),
        pw.Text('Stashes',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        _buildStashSection(stashesSorted, itemById),
      ],
    ),
  );

  final bytes = await pdf.save();
  final dir = await _tempDir();
  final file =
      File('${dir.path}/where_its_at_summary_${now.millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

pw.Widget _buildLoanSection(List<Loan> loans, Map<String, Item> itemById) {
  if (loans.isEmpty) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Text('None'),
    );
  }

  return pw.Column(
    children: loans.map((loan) {
      final item = itemById[loan.itemId];
      final String? thumbPath =
          (item != null && item.photos.isNotEmpty) ? item.photos.first : null;
      final Uint8List? bytes = (thumbPath != null) ? _tryLoadBytes(thumbPath) : null;

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (bytes != null)
              pw.Container(
                width: 32,
                height: 32,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
              ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: (item?.name ?? 'Unknown')),
                    const pw.TextSpan(text: ' • '),
                    pw.TextSpan(text: loan.person),
                    const pw.TextSpan(text: ' • Due: '),
                    pw.TextSpan(text: loan.dueOn != null ? _fmt(loan.dueOn) : 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}

pw.Widget _buildStashSection(List<Stash> stashes, Map<String, Item> itemById) {
  if (stashes.isEmpty) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Text('None'),
    );
  }

  return pw.Column(
    children: stashes.map((stash) {
      final item = itemById[stash.itemId];
      final String? thumbPath =
          (item != null && item.photos.isNotEmpty) ? item.photos.first : null;
      final Uint8List? bytes = (thumbPath != null) ? _tryLoadBytes(thumbPath) : null;

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (bytes != null)
              pw.Container(
                width: 32,
                height: 32,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
              ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: (item?.name ?? 'Unknown')),
                    const pw.TextSpan(text: ' • '),
                    pw.TextSpan(text: stash.placeName),
                    if ((stash.placeHint ?? '').isNotEmpty) ...const [
                      pw.TextSpan(text: ' • Hint: '),
                    ],
                    if ((stash.placeHint ?? '').isNotEmpty)
                      pw.TextSpan(text: stash.placeHint!),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}

// ----------------------------------------------------------------------
// Zip builders
// ----------------------------------------------------------------------

/// Build a complete export zip (items.csv, loans.csv, stashes.csv, summary.pdf).
Future<Uint8List> buildFullExportArchive({
  required List<Item> items,
  required List<Loan> loans,
  required List<Stash> stashes,
}) async {
  final archive = Archive();

  Future<void> addFileToArchive({
    required String name,
    required Future<File> Function() producer,
  }) async {
    final file = await producer();
    try {
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    } finally {
      await _tryDelete(file);
    }
  }

  await addFileToArchive(
    name: 'items.csv',
    producer: () => exportItemsCsv(items, loans, stashes),
  );
  await addFileToArchive(
    name: 'loans.csv',
    producer: () => exportLoansCsv(loans),
  );
  await addFileToArchive(
    name: 'stashes.csv',
    producer: () => exportStashesCsv(stashes),
  );
  await addFileToArchive(
    name: 'summary.pdf',
    producer: () => exportSummaryPdf(items: items, loans: loans, stashes: stashes),
  );

  final encoder = ZipEncoder();
  final data = encoder.encode(archive);
  return Uint8List.fromList(data);
}

Future<void> _tryDelete(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore cleanup failures; temporary files will be purged by the OS.
  }
}
