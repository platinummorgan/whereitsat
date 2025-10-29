import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../domain/stash.dart';
import '../domain/item.dart';
import '../data/providers.dart';
import 'add_item.dart';

class AddStashSheet extends ConsumerStatefulWidget {
  const AddStashSheet({super.key});
  @override
  ConsumerState<AddStashSheet> createState() => _AddStashSheetState();
}

class _AddStashSheetState extends ConsumerState<AddStashSheet> {
  String? _selectedItemId;
  String _placeName = '';
  String _placeHint = '';
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
    if (_placeName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place name required')));
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
    final repo = ref.read(stashRepoProvider);
    final now = DateTime.now();
    final stash = Stash(
      id: Uuid().v4(),
      itemId: _selectedItemId!,
      placeName: _placeName.trim(),
      placeHint: _placeHint.trim().isEmpty ? null : _placeHint.trim(),
      photo: _photo?.uri.toString(),
      storedOn: now,
      lastChecked: now,
    );
    await repo.add(stash);
    setState(() => _saving = false);
    if (mounted) {
      Navigator.of(context).pop(stash);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stash saved!')));
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
              decoration: const InputDecoration(labelText: 'Place Name *'),
              onChanged: (v) => _placeName = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Place Hint'),
              onChanged: (v) => _placeHint = v,
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Snap Location Photo'),
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
