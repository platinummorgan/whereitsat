import 'dart:io';
// import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

class ExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  static Future<File> exportItemCsv(Item item, List<Loan> loans, List<Stash> stashes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/item_${item.id}.csv');
    final buffer = StringBuffer();
    buffer.writeln('Item,Category,Created,Updated');
    buffer.writeln('${item.name},${item.category ?? ''},${_dateFormat.format(item.createdAt)},${_dateFormat.format(item.updatedAt)}');
    buffer.writeln('\nLoans:');
    buffer.writeln('Person,Contact,Due,Status,Notes');
    for (final loan in loans) {
      buffer.writeln('${loan.person},${loan.contact ?? ''},${loan.dueOn != null ? _dateFormat.format(loan.dueOn!) : ''},${loan.status.name},${loan.notes ?? ''}');
    }
    buffer.writeln('\nStashes:');
    buffer.writeln('Place,Hint,Photo,StoredOn,LastChecked');
    for (final stash in stashes) {
      buffer.writeln('${stash.placeName},${stash.placeHint ?? ''},${stash.photo ?? ''},${_dateFormat.format(stash.storedOn)},${stash.lastChecked != null ? _dateFormat.format(stash.lastChecked!) : ''}');
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  static Future<File> exportItemsCsv(List<Item> items, List<Loan> loans, List<Stash> stashes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/items.csv');
    final buffer = StringBuffer();
    buffer.writeln('ID,Name,Category,Created,Updated,Tags,Photos');
    for (final item in items) {
      buffer.writeln('${item.id},${item.name},${item.category ?? ''},${_dateFormat.format(item.createdAt)},${_dateFormat.format(item.updatedAt)},${item.tags.join('|')},${item.photos.join('|')}');
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  static Future<File> exportLoansCsv(List<Loan> loans) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/loans.csv');
    final buffer = StringBuffer();
    buffer.writeln('ID,ItemID,Person,Contact,LentOn,DueOn,Status,Notes,ReturnedOn,Where,Category');
    for (final loan in loans) {
      buffer.writeln('${loan.id},${loan.itemId},${loan.person},${loan.contact ?? ''},${_dateFormat.format(loan.lentOn)},${loan.dueOn != null ? _dateFormat.format(loan.dueOn!) : ''},${loan.status.name},${loan.notes ?? ''},${loan.returnedOn != null ? _dateFormat.format(loan.returnedOn!) : ''},${loan.where ?? ''},${loan.category ?? ''}');
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  static Future<File> exportStashesCsv(List<Stash> stashes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/stashes.csv');
    final buffer = StringBuffer();
    buffer.writeln('ID,ItemID,Place,Hint,Photo,StoredOn,LastChecked');
    for (final stash in stashes) {
      buffer.writeln('${stash.id},${stash.itemId},${stash.placeName},${stash.placeHint ?? ''},${stash.photo ?? ''},${_dateFormat.format(stash.storedOn)},${stash.lastChecked != null ? _dateFormat.format(stash.lastChecked!) : ''}');
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  static Future<File> exportSummaryPdf({
    required List<Item> items,
    required List<Loan> loans,
    required List<Stash> stashes,
  }) async {
    final pdf = pw.Document();
    final overdueLoans = loans.where((l) => l.dueOn != null && l.returnedOn == null && l.dueOn!.isBefore(DateTime.now())).toList();
    final activeLoans = loans.where((l) => l.returnedOn == null).toList();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('WhereItsAt Summary')),
          pw.Header(level: 1, child: pw.Text('Overdue Loans')),
          pw.Table.fromTextArray(
            headers: ['Item', 'Person', 'Due', 'Contact'],
            data: overdueLoans.map((l) {
              final item = items.firstWhere((i) => i.id == l.itemId, orElse: () => Item(id: '', name: '', createdAt: DateTime.now(), updatedAt: DateTime.now(), tags: [], photos: []));
              return [item.name, l.person, l.dueOn != null ? _dateFormat.format(l.dueOn!) : '', l.contact ?? ''];
            }).toList(),
          ),
          pw.Header(level: 1, child: pw.Text('Active Loans')),
          pw.Table.fromTextArray(
            headers: ['Item', 'Person', 'Due', 'Contact'],
            data: activeLoans.map((l) {
              final item = items.firstWhere((i) => i.id == l.itemId, orElse: () => Item(id: '', name: '', createdAt: DateTime.now(), updatedAt: DateTime.now(), tags: [], photos: []));
              return [item.name, l.person, l.dueOn != null ? _dateFormat.format(l.dueOn!) : '', l.contact ?? ''];
            }).toList(),
          ),
          pw.Header(level: 1, child: pw.Text('Stashes')),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stashes.map((stash) {
              pw.Widget? thumb;
              if (stash.photo != null && stash.photo!.isNotEmpty) {
                try {
                  final imgFile = File(stash.photo!);
                  if (imgFile.existsSync()) {
                    final imgBytes = imgFile.readAsBytesSync();
                    thumb = pw.Image(pw.MemoryImage(imgBytes), width: 32, height: 32);
                  }
                } catch (_) {}
              }
              return pw.Row(children: [
                if (thumb != null) thumb,
                pw.Text('${stash.placeName}${stash.placeHint != null ? ' (${stash.placeHint})' : ''}'),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/summary.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> shareFiles(List<File> files, {String? text}) async {
    final xfiles = files.map((f) => XFile(f.path)).toList();
    await Share.shareXFiles(xfiles, text: text ?? 'Exported data');
  }
}
