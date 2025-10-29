import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hive/hive.dart';

final reminderEnabledProvider = StateProvider<bool>((ref) => true);
final reminderTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 9, minute: 0));
final appLockEnabledProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) => AppLockNotifier());

class AppLockNotifier extends StateNotifier<bool> {
  static const _key = 'appLockEnabled';
  AppLockNotifier() : super(Hive.box('settings').get(_key, defaultValue: false));
  void set(bool v) {
    state = v;
    Hive.box('settings').put(_key, v);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(reminderEnabledProvider);
    final time = ref.watch(reminderTimeProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
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
          const Divider(),
          SwitchListTile(
            title: const Text('Require Face/PIN to open app'),
            value: appLockEnabled,
            onChanged: (v) async {
              ref.read(appLockEnabledProvider.notifier).set(v);
              if (v) {
                // Immediate auth
                // TODO: Show lock screen and require auth
              }
            },
          ),
        ],
      ),
    );
  }
}
