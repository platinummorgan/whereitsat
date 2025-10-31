import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../domain/stash.dart';
import 'item_detail.dart';

class ItemPill extends StatelessWidget {
  static String fmtDateTime(DateTime dt) {
    final date = "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "$date $time";
  }
  final Item item;
  final Loan? loan;
  final Stash? stash;
  final VoidCallback? onChanged;

  const ItemPill({
    super.key,
    required this.item,
    this.loan,
    this.stash,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
  final thumb = item.photos.isNotEmpty ? item.photos.first : '';
  final statusColor = loan?.status == LoanStatus.out
    ? Colors.deepPurple
    : loan?.status == LoanStatus.returned
      ? Colors.green
      : stash != null
        ? Colors.orange
        : Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(itemId: item.id),
          ),
        );
      },
      onLongPress: () async {
        HapticFeedback.mediumImpact();
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => Wrap(
            children: [
              if (loan?.status == LoanStatus.out) ...[
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in),
                  title: const Text('Mark Returned'),
                  onTap: () => Navigator.of(ctx).pop('returned'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Loan'),
                  onTap: () => Navigator.of(ctx).pop('edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Loan'),
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
              ],
              if (stash != null) ...[
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Mark Found'),
                  onTap: () => Navigator.of(ctx).pop('found'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Stash'),
                  onTap: () => Navigator.of(ctx).pop('edit_stash'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Stash'),
                  onTap: () => Navigator.of(ctx).pop('delete_stash'),
                ),
              ],
            ],
          ),
        );
        if (action == null) return;
        if (action == 'returned') {
          // TODO: Mark loan returned
          if (onChanged != null) onChanged!();
        } else if (action == 'edit') {
          // TODO: Edit loan
        } else if (action == 'delete') {
          // TODO: Delete loan
          if (onChanged != null) onChanged!();
        } else if (action == 'found') {
          // TODO: Mark stash found
          if (onChanged != null) onChanged!();
        } else if (action == 'edit_stash') {
          // TODO: Edit stash
        } else if (action == 'delete_stash') {
          // TODO: Delete stash
          if (onChanged != null) onChanged!();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: thumb.isNotEmpty
                  ? (thumb.startsWith('file://')
                      ? Image.file(
                          File(Uri.parse(thumb).toFilePath()),
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          thumb,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ))
                  : const Icon(Icons.inventory_2, size: 32),
            ),
            const SizedBox(width: 10),
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            if (loan?.dueOn != null)
              Text(
                ItemPill.fmtDateTime(loan!.dueOn!),
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );

  }
}
