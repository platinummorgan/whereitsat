// Export public API for import helpers
import 'dart:async';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import 'box_like.dart';

class ImportReport {
  final int itemsCreated;
  final int itemsUpdated;
  final int loansCreated;
  final int stashesCreated;
  final List<String> warnings;
  final List<String> errors;

  const ImportReport({
    required this.itemsCreated,
    required this.itemsUpdated,
    required this.loansCreated,
    required this.stashesCreated,
    required this.warnings,
    required this.errors,
  });
}

Future<ImportReport> importAllFromDirectory({
  required String directoryPath,
  required bool dryRun,
  required BoxLike<Item> itemBox,
  required BoxLike<Loan> loanBox,
  required BoxLike<Stash> stashBox,
}) async {
  // TODO: Implement directory scan, parse bundle JSON and CSVs, and apply import logic
  // For now, return a dummy report
  return ImportReport(
    itemsCreated: 0,
    itemsUpdated: 0,
    loansCreated: 0,
    stashesCreated: 0,
    warnings: [],
    errors: [],
  );
}
// lib/data/import.dart
//
// Robust importer for Items / Loans / Stashes from CSV or JSON.
// - No Riverpod/BuildContext required: pass your boxes in.
// - Async throughout (fixes "await in wrong context").
// - Handles nulls, flexible date formats, light validation.
// - No need for fromJson constructors in your domain models.
//
// Usage (example):
// final result = await importFromCsv(
//   itemBox: ref.read(itemBoxProvider),
//   loanBox: ref.read(loanBoxProvider),
//   stashBox: ref.read(stashBoxProvider),
//   itemsCsv: itemsCsvStringOrNull,
//   loansCsv: loansCsvStringOrNull,
//   stashesCsv: stashesCsvStringOrNull,
// );
//
// Or JSON:
// final result = await importFromJson(
//   itemBox: ref.read(itemBoxProvider),
//   loanBox: ref.read(loanBoxProvider),
//   stashBox: ref.read(stashBoxProvider),
//   json: decodedMap, // { items: [...], loans:[...], stashes:[...] }
// );

// (imports already present at top of file)

/// ------------------------ result model ------------------------

class ImportResult {
  final int itemsUpserted;
  final int loansUpserted;
  final int stashesUpserted;
  final List<String> warnings;
  final List<String> errors;

  const ImportResult({
    required this.itemsUpserted,
    required this.loansUpserted,
    required this.stashesUpserted,
    required this.warnings,
    required this.errors,
  });

  ImportResult copyWith({
    int? itemsUpserted,
    int? loansUpserted,
    int? stashesUpserted,
    List<String>? warnings,
    List<String>? errors,
  }) {
    return ImportResult(
      itemsUpserted: itemsUpserted ?? this.itemsUpserted,
      loansUpserted: loansUpserted ?? this.loansUpserted,
      stashesUpserted: stashesUpserted ?? this.stashesUpserted,
      warnings: warnings ?? this.warnings,
      errors: errors ?? this.errors,
    );
  }
}

/// ------------------------ parsing helpers ------------------------

String _normStr(dynamic v) => (v is String) ? v.trim() : (v == null ? '' : v.toString().trim());
String _normLower(dynamic v) => _normStr(v).toLowerCase();

String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

final DateFormat _isoNoMs = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
final DateFormat _dateOnly = DateFormat('yyyy-MM-dd');
final DateFormat _isoLocal = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
final DateFormat _dateSlashUSA = DateFormat('MM/dd/yyyy');

DateTime? _parseDate(dynamic raw) {
  final s = _normStr(raw);
  if (s.isEmpty) return null;
  final tryFormats = <DateFormat>[
    _dateOnly,       // yyyy-MM-dd
    _isoNoMs,        // yyyy-MM-ddTHH:mm:ssZ
    _isoLocal,       // yyyy-MM-ddTHH:mm:ss
    _dateSlashUSA,   // MM/dd/yyyy
  ];
  for (final fmt in tryFormats) {
    try {
      return fmt.parseUtc(s).toLocal();
    } catch (e) {
      try {
        return fmt.parse(s);
      } catch (e2) {
        // continue
      }
    }
  }
  // Last resort: DateTime.tryParse
  try {
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.toLocal();
  } catch (e) {
    // continue
  }
  return null;
}


List<String> _parseTags(dynamic raw) {
  final s = _normStr(raw);
  if (s.isEmpty) return const <String>[];
  // split on comma/semicolon
  return s
      .split(RegExp(r'[;,]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

T? _castOrNull<T>(dynamic v) => v is T ? v : null;

/// ------------------------ row->model mapping ------------------------

/// CSV Items header options we support
/// Item Name | Category | Tags
Item? _itemFromCsvRow(Map<String, String> row, List<String> problems) {
  String nameRaw = row['Item Name'] ?? row['Name'] ?? row['Item'] ?? '';
  String name = nameRaw.trim();
  if (name.isEmpty) {
    problems.add('Item row skipped: missing Item Name.');
    return null;
  }
  // Normalize for upserts: trim and lowercase
  name = name.toLowerCase();
  String category = _normStr(row['Category']);
  List<String> tags = _parseTags(row['Tags']);
  DateTime now = DateTime.now();
  return Item(
    id: _genId(),
    name: name,
    category: category.isEmpty ? null : category,
    tags: tags,
    photos: const <String>[],
    createdAt: now,
    updatedAt: now,
  );
}

/// CSV Loans header options we support
/// ItemId | Person | Contact | Lent On | Due On | Status | Returned On | Notes | Where | Category
Loan? _loanFromCsvRow(Map<String, String> row, List<String> problems) {
  String itemId = _normStr(row['ItemId'] ?? row['Item ID'] ?? '');
  if (itemId.isEmpty) {
    problems.add('Loan row skipped: missing ItemId.');
    return null;
  }
  String person = _normStr(row['Person']);
  if (person.isEmpty) {
    problems.add('Loan row skipped: missing Person (itemId=$itemId).');
    return null;
  }
  String contact = _normStr(row['Contact']);
  DateTime lentOn;
  try {
    lentOn = _parseDate(row['Lent On']) ?? DateTime.now();
  } catch (e) {
    problems.add('Loan row: Lent On date parse failed ($e)');
    lentOn = DateTime.now();
  }
  DateTime? dueOn;
  try {
    dueOn = _parseDate(row['Due On']);
  } catch (e) {
    problems.add('Loan row: Due On date parse failed ($e)');
    dueOn = null;
  }
  DateTime? returnedOn;
  try {
    returnedOn = _parseDate(row['Returned On']);
  } catch (e) {
    problems.add('Loan row: Returned On date parse failed ($e)');
    returnedOn = null;
  }
  String whereAt = _normStr(row['Where']);
  String category = _normStr(row['Category']);
  String notes = _normStr(row['Notes']);

  // status derivation: prefer explicit Status, else infer from returnedOn
  String statusRaw = _normLower(row['Status']);
  LoanStatus? status;
  if (statusRaw == 'returned') {
    status = LoanStatus.returned;
  } else if (statusRaw == 'out') {
    status = LoanStatus.out;
  } else if (statusRaw.isNotEmpty) {
    problems.add('Loan row: Unknown status "$statusRaw" (expected "out" or "returned"). Row skipped.');
    return null;
  } else if (returnedOn != null) {
    status = LoanStatus.returned;
  } else {
    status = LoanStatus.out;
  }

  return Loan(
    id: _genId(),
    itemId: itemId,
    person: person,
    contact: contact.isEmpty ? null : contact,
    lentOn: lentOn,
    dueOn: dueOn,
    status: status,
    notes: notes.isEmpty ? null : notes,
    returnPhoto: null,
    returnedOn: returnedOn,
    where: whereAt.isEmpty ? null : whereAt,
    category: category.isEmpty ? null : category,
  );
}

/// CSV Stashes header options we support
/// ItemId | Place Name | Hint | Stored On | Last Checked
Stash? _stashFromCsvRow(Map<String, String> row, List<String> problems) {
  final itemId = _normStr(row['ItemId'] ?? row['Item ID'] ?? '');
  if (itemId.isEmpty) {
    problems.add('Stash row skipped: missing ItemId.');
    return null;
  }
  final placeName = _normStr(row['Place Name'] ?? row['Place']);
  if (placeName.isEmpty) {
    problems.add('Stash row skipped: missing Place Name (itemId=$itemId).');
    return null;
  }

  final hint = _normStr(row['Hint']);
  final storedOn = _parseDate(row['Stored On']) ?? DateTime.now();
  final lastChecked = _parseDate(row['Last Checked']);

  return Stash(
    id: _genId(),
    itemId: itemId,
    placeName: placeName,
    placeHint: hint.isEmpty ? null : hint,
    photo: null,
    storedOn: storedOn,
    lastChecked: lastChecked,
  );
}

/// JSON -> Item mapping (minimal fields supported)
Item? _itemFromJson(Map<String, dynamic> j, List<String> problems) {
  final name = _normStr(j['name']);
  if (name.isEmpty) {
    problems.add('Item JSON skipped: missing name.');
    return null;
  }
  final category = _normStr(j['category']);
  final tags = _castOrNull<List>(j['tags'])?.map((e) => _normStr(e)).where((e) => e.isNotEmpty).toList() ?? <String>[];
  final photos = _castOrNull<List>(j['photos'])?.map((e) => _normStr(e)).where((e) => e.isNotEmpty).toList() ?? <String>[];

  final createdAt = _parseDate(j['createdAt']) ?? DateTime.now();
  final updatedAt = _parseDate(j['updatedAt']) ?? createdAt;

  return Item(
    id: _normStr(j['id']).isNotEmpty ? _normStr(j['id']) : _genId(),
    name: name,
    category: category.isEmpty ? null : category,
    tags: tags,
    photos: photos,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

Loan? _loanFromJson(Map<String, dynamic> j, List<String> problems) {
  final itemId = _normStr(j['itemId']);
  if (itemId.isEmpty) {
    problems.add('Loan JSON skipped: missing itemId.');
    return null;
  }
  final person = _normStr(j['person']);
  if (person.isEmpty) {
    problems.add('Loan JSON skipped: missing person (itemId=$itemId).');
    return null;
  }

  final lentOn = _parseDate(j['lentOn']) ?? DateTime.now();
  final dueOn = _parseDate(j['dueOn']);
  final returnedOn = _parseDate(j['returnedOn']);
  final statusStr = _normLower(j['status']);
  final status = () {
    if (statusStr == 'returned') return LoanStatus.returned;
    if (statusStr == 'out') return LoanStatus.out;
    if (returnedOn != null) return LoanStatus.returned;
    return LoanStatus.out;
  }();

  return Loan(
    id: _normStr(j['id']).isNotEmpty ? _normStr(j['id']) : _genId(),
    itemId: itemId,
    person: person,
    contact: _normStr(j['contact']).isEmpty ? null : _normStr(j['contact']),
    lentOn: lentOn,
    dueOn: dueOn,
    status: status,
    notes: _normStr(j['notes']).isEmpty ? null : _normStr(j['notes']),
    returnPhoto: _normStr(j['returnPhoto']).isEmpty ? null : _normStr(j['returnPhoto']),
    returnedOn: returnedOn,
    where: _normStr(j['where']).isEmpty ? null : _normStr(j['where']),
    category: _normStr(j['category']).isEmpty ? null : _normStr(j['category']),
  );
}

Stash? _stashFromJson(Map<String, dynamic> j, List<String> problems) {
  final itemId = _normStr(j['itemId']);
  if (itemId.isEmpty) {
    problems.add('Stash JSON skipped: missing itemId.');
    return null;
  }
  final placeName = _normStr(j['placeName'].toString().isEmpty ? j['place'] : j['placeName']);
  if (placeName.isEmpty) {
    problems.add('Stash JSON skipped: missing placeName (itemId=$itemId).');
    return null;
  }
  final storedOn = _parseDate(j['storedOn']) ?? DateTime.now();
  final lastChecked = _parseDate(j['lastChecked']);

  return Stash(
    id: _normStr(j['id']).isNotEmpty ? _normStr(j['id']) : _genId(),
    itemId: itemId,
    placeName: placeName,
    placeHint: _normStr(j['placeHint']).isEmpty ? null : _normStr(j['placeHint']),
    photo: _normStr(j['photo']).isEmpty ? null : _normStr(j['photo']),
    storedOn: storedOn,
    lastChecked: lastChecked,
  );
}

/// ------------------------ CSV import APIs ------------------------

/// Provide any of the csv strings; nulls are skipped.
/// Columns are matched case-sensitively by the mappers above.
Future<ImportResult> importFromCsv({
  required BoxLike<Item> itemBox,
  required BoxLike<Loan> loanBox,
  required BoxLike<Stash> stashBox,
  String? itemsCsv,
  String? loansCsv,
  String? stashesCsv,
}) async {
  int itemsCount = 0, loansCount = 0, stashesCount = 0;
  final warnings = <String>[];
  final errors = <String>[];

  Map<String, String> rowToMap(List<dynamic> header, List<dynamic> row) {
    final m = <String, String>{};
    for (int i = 0; i < header.length && i < row.length; i++) {
      m[_normStr(header[i])] = _normStr(row[i]);
    }
    return m;
  }

  Future<void> processCsv(
    String csv,
    Item? Function(Map<String, String>, List<String>)? itemMap,
    Loan? Function(Map<String, String>, List<String>)? loanMap,
    Stash? Function(Map<String, String>, List<String>)? stashMap,
  ) async {
    try {
      final table = const CsvToListConverter(eol: '\n').convert(csv);
      if (table.isEmpty) return;
      final header = table.first;
      for (int r = 1; r < table.length; r++) {
  final row = rowToMap(header, table[r]);
        try {
          if (itemMap != null) {
            final model = itemMap(row, warnings);
            if (model != null) {
              await itemBox.put(model.id, model);
              itemsCount++;
            }
          } else if (loanMap != null) {
            final model = loanMap(row, warnings);
            if (model != null) {
              await loanBox.put(model.id, model);
              loansCount++;
            }
          } else if (stashMap != null) {
            final model = stashMap(row, warnings);
            if (model != null) {
              await stashBox.put(model.id, model);
              stashesCount++;
            }
          }
        } catch (e, st) {
          errors.add('Row $r failed: $e');
          debugPrint('import row error: $e\n$st');
        }
      }
    } catch (e, st) {
      errors.add('CSV parse failed: $e');
      debugPrint('csv parse error: $e\n$st');
    }
  }

  if ((itemsCsv ?? '').trim().isNotEmpty) {
    await processCsv(itemsCsv!, _itemFromCsvRow, null, null);
  }
  if ((loansCsv ?? '').trim().isNotEmpty) {
    await processCsv(loansCsv!, null, _loanFromCsvRow, null);
  }
  if ((stashesCsv ?? '').trim().isNotEmpty) {
    await processCsv(stashesCsv!, null, null, _stashFromCsvRow);
  }

  return ImportResult(
    itemsUpserted: itemsCount,
    loansUpserted: loansCount,
    stashesUpserted: stashesCount,
    warnings: warnings,
    errors: errors,
  );
}

/// ------------------------ JSON import API ------------------------

/// Expects:
/// {
///   "items":   [ { ...Item-like... }, ... ],
///   "loans":   [ { ...Loan-like... }, ... ],
///   "stashes": [ { ...Stash-like... }, ... ]
/// }
Future<ImportResult> importFromJson({
  required BoxLike<Item> itemBox,
  required BoxLike<Loan> loanBox,
  required BoxLike<Stash> stashBox,
  required Map<String, dynamic> json,
}) async {
  int itemsCount = 0, loansCount = 0, stashesCount = 0;
  final warnings = <String>[];
  final errors = <String>[];

  List getList(String key) {
    final v = json[key];
    if (v is List) return v;
    if (v is String && v.trim().startsWith('[')) {
      try {
        final parsed = jsonDecode(v);
        if (parsed is List) return parsed;
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  final itemsJson = getList('items');
  for (int i = 0; i < itemsJson.length; i++) {
    final raw = itemsJson[i];
    if (raw is Map<String, dynamic>) {
      try {
        final model = _itemFromJson(raw, warnings);
        if (model != null) {
          await itemBox.put(model.id, model);
          itemsCount++;
        }
      } catch (e, st) {
        errors.add('items[$i] failed: $e');
        debugPrint('item json error: $e\n$st');
      }
    } else {
      warnings.add('items[$i] skipped (not an object)');
    }
  }

  final loansJson = getList('loans');
  for (int i = 0; i < loansJson.length; i++) {
    final raw = loansJson[i];
    if (raw is Map<String, dynamic>) {
      try {
        final model = _loanFromJson(raw, warnings);
        if (model != null) {
          await loanBox.put(model.id, model);
          loansCount++;
        }
      } catch (e, st) {
        errors.add('loans[$i] failed: $e');
        debugPrint('loan json error: $e\n$st');
      }
    } else {
      warnings.add('loans[$i] skipped (not an object)');
    }
  }

  final stashesJson = getList('stashes');
  for (int i = 0; i < stashesJson.length; i++) {
    final raw = stashesJson[i];
    if (raw is Map<String, dynamic>) {
      try {
        final model = _stashFromJson(raw, warnings);
        if (model != null) {
          await stashBox.put(model.id, model);
          stashesCount++;
        }
      } catch (e, st) {
        errors.add('stashes[$i] failed: $e');
        debugPrint('stash json error: $e\n$st');
      }
    } else {
      warnings.add('stashes[$i] skipped (not an object)');
    }
  }

  return ImportResult(
    itemsUpserted: itemsCount,
    loansUpserted: loansCount,
    stashesUpserted: stashesCount,
    warnings: warnings,
    errors: errors,
  );
}
