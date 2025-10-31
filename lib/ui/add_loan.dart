// lib/ui/add_loan.dart
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/notifications.dart';
import '../data/providers.dart';
import '../domain/item.dart';
import '../domain/loan.dart';
import '../ui/settings.dart'; // reminderEnabledProvider, reminderTimeProvider


class AddLoanSheet extends ConsumerStatefulWidget {
  final Loan? loan;
  const AddLoanSheet({super.key, this.loan});

  @override
  ConsumerState<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<AddLoanSheet> {
  // form state
  String _person = '';
  String _what = '';
  String _where = '';
  String _category = '';
  String _contact = '';
  String _notes = '';

  DateTime? _dueOn;

  File? _photo;
  bool _saving = false;

  final _personController = TextEditingController();
  final List<String> _recentPeople = <String>[];

  @override
  void initState() {
    super.initState();

    // If editing, prefill.
    final existing = widget.loan;
    if (existing != null) {
      _person = existing.person;
      // NOTE: We don't have the Item name here; this sheet currently creates a new Item on save.
      _what = '';
      _where = existing.where ?? '';
      _category = existing.category ?? '';
      _contact = existing.contact ?? '';
      _notes = existing.notes ?? '';
      _dueOn = existing.dueOn;
  // _preset removed
      _personController.text = _person;
    }

    // Load recent people from existing loans (best-effort).
    Future.microtask(() async {
      final loanBox = ref.read(loanBoxProvider);
      final all = loanBox.values.toList();
      final names = <String>{};
      for (final l in all) {
        final n = l.person.trim();
        if (n.isNotEmpty) names.add(n);
      }
      if (!mounted) return;
      setState(() {
        _recentPeople
          ..clear()
          ..addAll(names.take(30));
      });
    });
  }

  @override
  void dispose() {
    _personController.dispose();
    super.dispose();
  }




  Future<void> _pickPhoto(ImageSource source) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos are not supported on web yet.')),
      );
      return;
    }

    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/${const Uuid().v4()}.jpg');
      final file = await File(picked.path).copy(dest.path);

      if (!mounted) return;
      setState(() => _photo = file);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera or storage permission denied.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              // If you added app_settings:
              // AppSettings.openAppSettings();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _save() async {
    // Guard rails
    if (_person.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Who is required')));
      return;
    }
    if (_what.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('What is required')));
      return;
    }

    // Prevent saving if due date/time is in the past
    if (_dueOn != null) {
      final now = DateTime.now();
      if (_dueOn!.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Due date/time must be in the future.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final loanBox = ref.read(loanBoxProvider);
    final itemBox = ref.read(itemBoxProvider);
    final now = DateTime.now();

    try {
      // Create the item this loan refers to
      final item = Item(
        id: const Uuid().v4(),
        name: _what.trim(),
        category: _category.trim().isEmpty ? null : _category.trim(),
        photos: _photo != null ? <String>[_photo!.uri.toString()] : const <String>[],
        tags: const <String>[],
        createdAt: now,
        updatedAt: now,
      );
      await itemBox.put(item.id, item);

      final loan = Loan(
        id: const Uuid().v4(),
        itemId: item.id,
        person: _person.trim(),
        contact: _contact.trim().isEmpty ? null : _contact.trim(),
        lentOn: now,
        dueOn: _dueOn,
        status: LoanStatus.out,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        returnPhoto: _photo?.uri.toString(),
        returnedOn: null,
        where: _where.trim().isEmpty ? null : _where.trim(),
        category: _category.trim().isEmpty ? null : _category.trim(),
      );
      await loanBox.put(loan.id, loan);

      // Schedule a reminder if enabled + due date is set (mobile/desktop only)
      final remindersEnabled = ref.read(reminderEnabledProvider);
      final reminderTime = ref.read(reminderTimeProvider); // TimeOfDay
      if (loan.dueOn != null && remindersEnabled && !kIsWeb) {
        await requestNotificationPermission();
        await scheduleLoanNotification(
          loanId: loan.id,
          itemName: item.name, // use item name, not itemId
          dueDate: loan.dueOn!,
          reminderTime: reminderTime,
          oneDayBefore: true,
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(loan);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Loan saved!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving loan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _person.trim().isNotEmpty && _what.trim().isNotEmpty && !_saving;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // WHO (with recent names autocomplete)
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue tev) {
                if (tev.text.isEmpty) return const Iterable<String>.empty();
                final q = tev.text.toLowerCase();
                return _recentPeople.where((p) => p.toLowerCase().contains(q));
              },
              onSelected: (String selection) {
                _personController.text = selection;
                setState(() => _person = selection);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text.isEmpty && _personController.text.isNotEmpty) {
                  controller.text = _personController.text;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Who *'),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => setState(() => _person = v),
                  );
                },
              ),

            TextField(
              decoration: const InputDecoration(labelText: 'What *'),
              textInputAction: TextInputAction.next,
              onChanged: (v) => setState(() => _what = v),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Where'),
              textInputAction: TextInputAction.next,
              onChanged: (v) => _where = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Category'),
              textInputAction: TextInputAction.next,
              onChanged: (v) => _category = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Contact'),
              textInputAction: TextInputAction.next,
              onChanged: (v) => _contact = v,
            ),
            const SizedBox(height: 8),

            // Due date/time picker
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueOn == null
                          ? 'No due date selected'
                          : 'Due: ${_dueOn!.toLocal().toString().substring(0, 16)}',
                      style: TextStyle(
                        color: _dueOn == null
                            ? Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)
                            : Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: _dueOn == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Due Date'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _dueOn ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_dueOn ?? DateTime.now()),
                        );
                        if (pickedTime != null) {
                          final combined = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                          setState(() => _dueOn = combined);
                        } else {
                          setState(() => _dueOn = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                          ));
                        }
                      }
                    },
                  ),
                  if (_dueOn != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => _dueOn = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
              onChanged: (v) => _notes = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Snap Photo'),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_photo!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
