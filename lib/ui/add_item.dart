import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/item.dart';
import '../data/providers.dart';

class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({Key? key}) : super(key: key);
  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  List<File> _photos = [];
  bool _saving = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final file = await File(picked.path).copy('${dir.path}/${Uuid().v4()}.jpg');
      setState(() => _photos.add(file));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(itemRepoProvider);
    final now = DateTime.now();
    final item = Item(
      id: Uuid().v4(),
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      tags: _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      photos: _photos.map((f) => f.uri.toString()).toList(),
      createdAt: now,
      updatedAt: now,
    );
    await repo.add(item);
    setState(() => _saving = false);
    if (mounted) {
      Navigator.of(context).pop(item);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item saved!')));
      // TODO: Navigate to ItemDetail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category')),
            TextField(controller: _tagsController, decoration: const InputDecoration(labelText: 'Tags (comma separated)')),
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
            if (_photos.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _photos.map((f) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.file(f, width: 64, height: 64, fit: BoxFit.cover),
                  )).toList(),
                ),
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
