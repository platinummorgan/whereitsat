import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../domain/item.dart';
import '../domain/stash.dart';
import '../data/providers.dart';
import '../data/photo_copy.dart';

class NewStashScreen extends ConsumerStatefulWidget {
  const NewStashScreen({super.key});
  @override
  ConsumerState<NewStashScreen> createState() => _NewStashScreenState();
}

class _NewStashScreenState extends ConsumerState<NewStashScreen> {
  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  final _hintController = TextEditingController();
  Map<String, String>? _photo;
  bool _saving = false;
  List<String> _recentPlaces = [];

  @override
  void initState() {
    super.initState();
  final stashBox = ref.read(stashBoxProvider);
  _recentPlaces = stashBox.values.map((s) => s.placeName).toSet().toList();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final itemId = Uuid().v4();
        final result = await copyAndThumb(picked.path, itemId);
        setState(() => _photo = result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera or storage permission denied.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              // Open app settings
              // import 'package:app_settings/app_settings.dart'; AppSettings.openAppSettings();
            },
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name required')));
      return;
    }
    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place name required')));
      return;
    }
    setState(() => _saving = true);
  final itemBox = ref.read(itemBoxProvider);
  final stashBox = ref.read(stashBoxProvider);
    final now = DateTime.now();
    final itemId = Uuid().v4();
    final item = Item(
      id: itemId,
      name: _nameController.text.trim(),
      createdAt: now,
      updatedAt: now,
      photos: _photo != null ? [_photo!['path']!] : [],
      tags: [],
    );
  await itemBox.put(item.id, item);
    final stash = Stash(
      id: Uuid().v4(),
      itemId: item.id,
      placeName: _placeController.text.trim(),
      placeHint: _hintController.text.trim().isEmpty ? null : _hintController.text.trim(),
      photo: _photo != null ? _photo!['path'] : null,
      storedOn: now,
      lastChecked: null,
    );
  await stashBox.put(stash.id, stash);
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop(stash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Stash')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Item Name *')),
            TextField(controller: _placeController, decoration: const InputDecoration(labelText: 'Place Name *')),
            Wrap(
              spacing: 8,
              children: _recentPlaces.map((place) => ActionChip(
                label: Text(place),
                onPressed: () => _placeController.text = place,
              )).toList(),
            ),
            TextField(controller: _hintController, decoration: const InputDecoration(labelText: 'Place Hint')),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Photo'),
                  onPressed: _pickPhoto,
                ),
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Image.file(File(_photo!['thumbPath']!), width: 60, height: 60, fit: BoxFit.cover),
                  ),
              ],
            ),
            const Spacer(),
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
