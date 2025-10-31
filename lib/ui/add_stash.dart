import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import '../domain/stash.dart';
import '../domain/item.dart';
import '../data/providers.dart';
import '../data/photo_copy.dart';

class AddStashSheet extends ConsumerStatefulWidget {
  const AddStashSheet({super.key});
  @override
  ConsumerState<AddStashSheet> createState() => _AddStashSheetState();
}

class _AddStashSheetState extends ConsumerState<AddStashSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _placeController = TextEditingController();
  final _hintController = TextEditingController();

  final List<String> _recentPlaces = [];
  Map<String, String>? _photo;
  bool _saving = false;
  bool _returned = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        final itemId = const Uuid().v4();
        final result = await copyAndThumb(picked.path, itemId);
        if (!mounted) return;
        setState(() => _photo = result);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera or storage permission denied.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              // AppSettings.openAppSettings();  // add package if you want
            },
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }
    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Where its at? required')));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final itemBox = ref.read(itemBoxProvider);
    final stashBox = ref.read(stashBoxProvider);

    final now = DateTime.now();
    final itemId = const Uuid().v4();

    final item = Item(
      id: itemId,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      tags: const [],
      photos: _photo != null ? [_photo!['path']!] : const [],
      createdAt: now,
      updatedAt: now,
    );
    await itemBox.put(item.id, item);

    final stash = Stash(
      id: const Uuid().v4(),
      itemId: item.id,
      placeName: _placeController.text.trim(),
      placeHint:
          _hintController.text.trim().isEmpty ? null : _hintController.text.trim(),
      photo: _photo != null ? _photo!['path'] : null,
      storedOn: now,
      lastChecked: null,
      returnedOn: _returned ? now : null,
    );
    await stashBox.put(stash.id, stash);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(stash);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: insets.bottom > 0 ? 48.0 : 120.0,
          bottom: insets.bottom + 16.0,
          left: 16.0,
          right: 16.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Switch(
                    value: _returned,
                    onChanged: (v) => setState(() => _returned = v),
                    activeThumbColor: Colors.green,
                  ),
                  const Text('Returned', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              // Header: title centered, arrow in the top-right
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Add Stash',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                textInputAction: TextInputAction.next,
              ),

              Autocomplete<String>(
                optionsBuilder: (TextEditingValue tev) {
                  if (tev.text.isEmpty) return const Iterable<String>.empty();
                  final q = tev.text.toLowerCase();
                  return _recentPlaces.where((p) => p.toLowerCase().contains(q));
                },
                onSelected: (String selection) {
                  _placeController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Mirror internal controller with ours
                  if (controller.text.isEmpty && _placeController.text.isNotEmpty) {
                    controller.text = _placeController.text;
                  }
                  return TextField(
                    controller: _placeController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Where its at? *'),
                    textInputAction: TextInputAction.next,
                  );
                },
              ),

              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _hintController,
                decoration: const InputDecoration(labelText: 'Hint'),
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 12),
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
                      child: Image.file(
                        File(_photo!['thumbPath']!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
