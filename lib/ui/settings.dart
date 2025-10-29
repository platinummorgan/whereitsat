import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final reminderEnabledProvider = StateProvider<bool>((ref) => true);
final reminderTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 9, minute: 0));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(reminderEnabledProvider);
    final time = ref.watch(reminderTimeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Reminders'),
            value: enabled,
            onChanged: (v) => ref.read(reminderEnabledProvider.notifier).state = v,
          ),
          ListTile(
            title: const Text('Default Reminder Time'),
            subtitle: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: time);
              if (picked != null) ref.read(reminderTimeProvider.notifier).state = picked;
            },
          ),
        ],
      ),
    );
  }
}
