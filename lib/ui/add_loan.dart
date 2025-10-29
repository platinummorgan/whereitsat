import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../domain/loan.dart';
import '../domain/item.dart';
import '../data/providers.dart';
import '../data/notifications.dart';
import '../ui/settings.dart';
import 'add_item.dart';

class AddLoanSheet extends ConsumerStatefulWidget {
  const AddLoanSheet({super.key});
  @override
  ConsumerState<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<AddLoanSheet> {
  String? _selectedItemId;
  String _person = '';
  String _contact = '';
  DateTime? _dueOn;
  String _notes = '';
  File? _photo;
  bool _saving = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = await File(picked.path).copy('${dir.path}/${Uuid().v4()}.jpg');
        setState(() => _photo = file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera or storage permission denied.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              // Open app settings
              // ...existing code...
            },
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_person.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Person required')));
      return;
    }
    if (_selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select or create an item')));
      return;
    }
  setState(() => _saving = true);
  HapticFeedback.lightImpact();
    import 'package:flutter/services.dart';
    HapticFeedback.lightImpact();
  final repo = ref.read(loanRepoProvider);
  final itemRepo = ref.read(itemRepoProvider);
    final now = DateTime.now();
    final loan = Loan(
      id: Uuid().v4(),
      itemId: _selectedItemId!,
      person: _person.trim(),
      contact: _contact.trim().isEmpty ? null : _contact.trim(),
      lentOn: now,
      dueOn: _dueOn,
      status: LoanStatus.out,
      notes: _notes.trim().isEmpty ? null : _notes.trim(),
      returnPhoto: _photo?.uri.toString(),
      returnedOn: null,
    );
    await repo.add(loan);
    // Schedule notification if dueOn is set and reminders enabled
    final remindersEnabled = ref.read(reminderEnabledProvider);
    final reminderTime = ref.read(reminderTimeProvider);
    if (loan.dueOn != null && remindersEnabled) {
      await scheduleLoanNotification(
        loanId: loan.id,
        itemName: itemRepo.get(loan.itemId)?.name ?? '',
        dueDate: loan.dueOn!,
        reminderTime: reminderTime,
        oneDayBefore: true,
      );
    }
    setState(() => _saving = false);
    if (mounted) {
      Navigator.of(context).pop(loan);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan saved!')));
      // TODO: Navigate to ItemDetail
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemRepo = ref.watch(itemRepoProvider);
    final items = itemRepo.list();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedItemId,
              items: items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
              onChanged: (v) => setState(() => _selectedItemId = v),
              decoration: const InputDecoration(labelText: 'Item'),
            ),
            TextButton(
              child: const Text('Create new item'),
              onPressed: () async {
                final item = await showModalBottomSheet<Item>(context: context, builder: (_) => const AddItemSheet());
                if (item != null) setState(() => _selectedItemId = item.id);
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Person *'),
              onChanged: (v) => _person = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Contact'),
              onChanged: (v) => _contact = v,
            ),
            Row(
              children: [
                ...[3, 7, 14].map((d) => ChoiceChip(
                  label: Text('$d days'),
                  selected: _dueOn == DateTime.now().add(Duration(days: d)),
                  onSelected: (_) => setState(() => _dueOn = DateTime.now().add(Duration(days: d))),
                )),
                TextButton(
                  child: const Text('Custom'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueOn = picked);
                  },
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
              onChanged: (v) => _notes = v,
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Snap Photo'),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(_photo!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
