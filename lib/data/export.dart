import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';

Future<File> exportItemsCsv(List<Item> items, List<Loan> loans, List<Stash> stashes) async {
  final rows = <List<String>>[];
  rows.add(['Item Name', 'Category', 'Tags', 'Status', 'Person', 'Due', 'Place', 'Hint']);
  for (final item in items) {
    final latestLoan = loans.where((l) => l.itemId == item.id).toList().reversed.firstWhere((_) => true, orElse: () => null);
    final latestStash = stashes.where((s) => s.itemId == item.id).toList().reversed.firstWhere((_) => true, orElse: () => null);
    rows.add([
      item.name,
      item.category ?? '',
      item.tags.join(','),
      latestLoan != null ? (latestLoan.status == LoanStatus.out ? 'Out' : 'Returned') : (latestStash != null ? 'Stashed' : 'None'),
      latestLoan?.person ?? '',
      latestLoan?.dueOn?.toIso8601String() ?? '',
      latestStash?.placeName ?? '',
      latestStash?.placeHint ?? '',
    ]);
  }
  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/who_has_it_items_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

Future<File> exportLoansCsv(List<Loan> loans) async {
  final rows = <List<String>>[];
  rows.add(['ItemId', 'Person', 'Contact', 'Lent On', 'Due On', 'Status', 'Returned On']);
  for (final loan in loans) {
    rows.add([
      loan.itemId,
      loan.person,
      loan.contact ?? '',
      loan.lentOn.toIso8601String(),
      loan.dueOn?.toIso8601String() ?? '',
      loan.status.name,
      loan.returnedOn?.toIso8601String() ?? '',
    ]);
  }
  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/who_has_it_loans_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

Future<File> exportStashesCsv(List<Stash> stashes) async {
  final rows = <List<String>>[];
  rows.add(['ItemId', 'Place Name', 'Hint', 'Stored On', 'Last Checked']);
  for (final stash in stashes) {
    rows.add([
      stash.itemId,
      stash.placeName,
      stash.placeHint ?? '',
      stash.storedOn.toIso8601String(),
      stash.lastChecked?.toIso8601String() ?? '',
    ]);
  }
  final csvStr = const ListToCsvConverter().convert(rows);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/who_has_it_stashes_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csvStr);
  return file;
}

Future<File> exportSummaryPdf({
  required List<Item> items,
  required List<Loan> loans,
  required List<Stash> stashes,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Who Has It? – Summary (${now.year}-${now.month}-${now.day})')),
        pw.Paragraph(text: 'Overdue Loans'),
        _buildLoanSection(loans.where((l) => l.status == LoanStatus.out && l.dueOn != null && l.dueOn!.isBefore(now)).toList(), items),
        pw.Paragraph(text: 'Active Loans'),
        _buildLoanSection(loans.where((l) => l.status == LoanStatus.out && (l.dueOn == null || l.dueOn!.isAfter(now))).toList(), items),
        pw.Paragraph(text: 'Stashes'),
        _buildStashSection(stashes, items),
      ],
    ),
  );
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/who_has_it_summary_${now.millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}

pw.Widget _buildLoanSection(List<Loan> loans, List<Item> items) {
  return pw.Column(
    children: loans.map((loan) {
      final item = items.firstWhere((i) => i.id == loan.itemId, orElse: () => null);
      final photo = item?.photos.isNotEmpty == true ? item!.photos.first : null;
      return pw.Row(children: [
        if (photo != null)
          pw.Container(width: 32, height: 32, child: pw.Image(pw.MemoryImage(File(Uri.parse(photo).path).readAsBytesSync()), fit: pw.BoxFit.cover)),
        pw.Text(item?.name ?? 'Unknown'),
        pw.Text(' • ${loan.person}'),
        pw.Text(' • Due: ${loan.dueOn != null ? '${loan.dueOn!.year}-${loan.dueOn!.month}-${loan.dueOn!.day}' : 'N/A'}'),
      ]);
    }).toList(),
  );
}

pw.Widget _buildStashSection(List<Stash> stashes, List<Item> items) {
  return pw.Column(
    children: stashes.map((stash) {
      final item = items.firstWhere((i) => i.id == stash.itemId, orElse: () => null);
      final photo = item?.photos.isNotEmpty == true ? item!.photos.first : null;
      return pw.Row(children: [
        if (photo != null)
          pw.Container(width: 32, height: 32, child: pw.Image(pw.MemoryImage(File(Uri.parse(photo).path).readAsBytesSync()), fit: pw.BoxFit.cover)),
        pw.Text(item?.name ?? 'Unknown'),
        pw.Text(' • ${stash.placeName}'),
        pw.Text(' • Hint: ${stash.placeHint ?? ''}'),
      ]);
    }).toList(),
  );
}
