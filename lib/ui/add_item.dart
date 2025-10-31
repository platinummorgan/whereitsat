// add_item.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/photo_copy.dart';
import '../data/providers.dart';
import '../domain/item.dart';

class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key});

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<String> _tags = <String>[];
  /// Each entry: {'path': fullPath, 'thumbPath': thumbPath}
  final List<Map<String, String>> _photos = <Map<String, String>>[];

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      // Use a stable itemId placeholder before save; the actual item id is created on save.
      final tempId = const Uuid().v4();
      final result = await copyAndThumb(picked.path, tempId);
      if (!mounted) return;
      setState(() => _photos.add(result));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera or storage permission denied.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              // If you’ve added app_settings, uncomment:
              // AppSettings.openAppSettings();
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to pick image.')));
    }
  }

  void _parseTags(String v) {
    final parsed = v
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet() // dedupe
        .toList();
    setState(() {
      _tags
        ..clear()
        ..addAll(parsed);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final box = ref.read(itemBoxProvider);
    final now = DateTime.now();
    final itemId = const Uuid().v4();

    final item = Item(
      id: itemId,
      name: name,
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      tags: List<String>.from(_tags),
      photos: _photos.map((f) => f['path']!).toList(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await box.put(item.id, item);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(item);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item saved!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty && !_saving;

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
                const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name *'),
              onChanged: (_) => setState(() {}), // update Save button state
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration:
                  const InputDecoration(labelText: 'Tags (comma separated)'),
              onChanged: _parseTags,
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: -8,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setState(() {
                            _tags.remove(tag);
                            _tagsController.text = _tags.join(', ');
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
              ],
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.file(
                          File(_photos[i]['thumbPath']!),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => setState(() {
                            _photos.removeAt(i);
                          }),
                        ),
                      ),
                    ],
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemCount: _photos.length,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
