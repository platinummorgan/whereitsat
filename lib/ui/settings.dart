// lib/ui/settings.dart
import 'package:where_its_at/ui/policy_page.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import 'package:where_its_at/data/export.dart';
import 'package:where_its_at/data/notifications.dart';
import 'package:where_its_at/data/providers.dart';
import 'package:where_its_at/data/import.dart';

// ---------- Settings keys ----------
const _kAppLockEnabled   = 'appLockEnabled';
const _kRemindersEnabled = 'remindersEnabled';
const _kReminderHour     = 'reminderHour';
const _kReminderMinute   = 'reminderMinute';
const _kShowThumbs       = 'showThumbnails';
const _kOnboardingSeen   = 'onboardingSeen';

// ---------- Theme mode ----------
enum ThemeModeSetting { system, light, dark }

ThemeMode themeModeFromSetting(ThemeModeSetting setting) {
  switch (setting) {
    case ThemeModeSetting.light:  return ThemeMode.light;
    case ThemeModeSetting.dark:   return ThemeMode.dark;
    case ThemeModeSetting.system: return ThemeMode.system;
  }
}

ThemeModeSetting themeModeSettingFromString(String? value) {
  switch (value) {
    case 'light':  return ThemeModeSetting.light;
    case 'dark':   return ThemeModeSetting.dark;
    case 'system':
    default:       return ThemeModeSetting.system;
  }
}

// ---------- Notifiers ----------
class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier()
      : super(Hive.box('settings').get(_kAppLockEnabled, defaultValue: false) as bool);
  void set(bool v) {
    state = v;
    Hive.box('settings').put(_kAppLockEnabled, v);
  }
}

class RemindersEnabledNotifier extends StateNotifier<bool> {
  RemindersEnabledNotifier()
      : super(Hive.box('settings').get(_kRemindersEnabled, defaultValue: true) as bool);

  Future<void> set(BuildContext context, bool v) async {
    state = v;
    Hive.box('settings').put(_kRemindersEnabled, v);
    if (v) {
      await requestNotificationPermission();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission requested')),
        );
      }
      await rescheduleAllDueNotifications();
    } else {
      await cancelAllScheduledNotifications();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminders disabled')),
        );
      }
    }
  }
}

class ReminderTimeNotifier extends StateNotifier<TimeOfDay> {
  ReminderTimeNotifier()
      : super(TimeOfDay(
          hour: Hive.box('settings').get(_kReminderHour, defaultValue: 9) as int,
          minute: Hive.box('settings').get(_kReminderMinute, defaultValue: 0) as int,
        ));

  Future<void> set(TimeOfDay t) async {
    state = t;
    final box = Hive.box('settings');
    await box.put(_kReminderHour, t.hour);
    await box.put(_kReminderMinute, t.minute);
    await rescheduleAllDueNotifications();
  }
}

class ShowThumbnailsNotifier extends StateNotifier<bool> {
  ShowThumbnailsNotifier()
      : super(Hive.box('settings').get(_kShowThumbs, defaultValue: true) as bool);
  void set(bool v) {
    state = v;
    Hive.box('settings').put(_kShowThumbs, v);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeModeSetting> {
  static const _kThemeMode = 'themeMode';
  ThemeModeNotifier()
      : super(
          themeModeSettingFromString(
            Hive.box('settings').get(_kThemeMode, defaultValue: 'system') as String?,
          ),
        );
  void set(ThemeModeSetting mode) {
    state = mode;
    Hive.box('settings').put(_kThemeMode, mode.name);
  }
}

// ---------- Providers ----------
final appLockEnabledProvider =
    StateNotifierProvider<AppLockNotifier, bool>((_) => AppLockNotifier());

final reminderEnabledProvider =
    StateNotifierProvider<RemindersEnabledNotifier, bool>((_) => RemindersEnabledNotifier());

final reminderTimeProvider =
    StateNotifierProvider<ReminderTimeNotifier, TimeOfDay>((_) => ReminderTimeNotifier());

final showThumbnailsProvider =
    StateNotifierProvider<ShowThumbnailsNotifier, bool>((_) => ShowThumbnailsNotifier());

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>((_) => ThemeModeNotifier());

// ---------- Screen ----------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ----- Import -----
  Future<void> _importAll(BuildContext context, WidgetRef ref, {required bool dryRun}) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import is not supported on Web')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select import file',
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'zip'],
      allowMultiple: false,
    );
    if (!context.mounted) return;
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final itemBox  = ref.read(itemBoxProvider);
    final loanBox  = ref.read(loanBoxProvider);
    final stashBox = ref.read(stashBoxProvider);

    final report = await importAllFromDirectory(
      directoryPath: filePath,
      dryRun: dryRun,
      itemBox: itemBox,
      loanBox: loanBox,
      stashBox: stashBox,
    );
    if (!context.mounted) return;

    final summary = 'Items: +${report.itemsCreated} / ~${report.itemsUpdated} updated\n'
        'Loans: +${report.loansCreated}\n'
        'Stashes: +${report.stashesCreated}\n'
        'Warnings: ${report.warnings.length}';

    if (dryRun) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Dry-Run'),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (!context.mounted) return;

    // Confirm real import
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: Text('Apply the following changes?\n\n$summary'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (confirmed != true) return;

    final realReport = await importAllFromDirectory(
      directoryPath: filePath,
      dryRun: false,
      itemBox: itemBox,
      loanBox: loanBox,
      stashBox: stashBox,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Import complete: '
          'Items +${realReport.itemsCreated}/~${realReport.itemsUpdated}, '
          'Loans +${realReport.loansCreated}, '
          'Stashes +${realReport.stashesCreated}, '
          'Warnings ${realReport.warnings.length}',
        ),
        action: realReport.warnings.isNotEmpty
            ? SnackBarAction(
                label: 'View',
                onPressed: () {
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Import Warnings'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: realReport.warnings.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(realReport.warnings[i]),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  // ----- Export -----
  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not supported on Web')),
      );
      return;
    }

    final itemBox  = ref.read(itemBoxProvider);
    final loanBox  = ref.read(loanBoxProvider);
    final stashBox = ref.read(stashBoxProvider);

    final items   = itemBox.values.toList();
    final loans   = loanBox.values.toList();
    final stashes = stashBox.values.toList();

    // Selection dialog
    final selections = await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) {
        final Map<String, bool> selected = {
          'items.csv': true,
          'loans.csv': true,
          'stashes.csv': true,
          'summary.pdf': true,
        };
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select files to export'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Items (CSV)'),
                  value: selected['items.csv'],
                  onChanged: (v) => setState(() => selected['items.csv'] = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Loans (CSV)'),
                  value: selected['loans.csv'],
                  onChanged: (v) => setState(() => selected['loans.csv'] = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Stashes (CSV)'),
                  value: selected['stashes.csv'],
                  onChanged: (v) => setState(() => selected['stashes.csv'] = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Summary (PDF)'),
                  value: selected['summary.pdf'],
                  onChanged: (v) => setState(() => selected['summary.pdf'] = v ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Export'),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    if (selections == null) return;

    try {
  final filesToInclude = <String, Future<File> Function()>{};
      if (selections['items.csv'] == true) {
        filesToInclude['items.csv'] = () => exportItemsCsv(items, loans, stashes);
      }
      if (selections['loans.csv'] == true) {
        filesToInclude['loans.csv'] = () => exportLoansCsv(loans);
      }
      if (selections['stashes.csv'] == true) {
        filesToInclude['stashes.csv'] = () => exportStashesCsv(stashes);
      }
      if (selections['summary.pdf'] == true) {
        filesToInclude['summary.pdf'] = () => exportSummaryPdf(items: items, loans: loans, stashes: stashes);
      }

      final archiveBytes = await buildExportArchiveWithSelection(filesToInclude);
      if (!context.mounted) return;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final baseName = 'where_its_at_export_$timestamp';

      final savedPath = await FileSaver.instance.saveAs(
        name: baseName,
        bytes: archiveBytes,
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
      if (!context.mounted) return;

      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export canceled')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export saved ($baseName.zip)'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () async {
              if (!context.mounted) return;
              try {
                await Share.shareXFiles(
                  [
                    XFile.fromData(
                      archiveBytes,
                      name: '$baseName.zip',
                      mimeType: 'application/zip',
                    ),
                  ],
                  text: 'Exported selected data',
                );
              } catch (err) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Share failed: $err')),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ----- Delete all -----
  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final itemBox  = ref.read(itemBoxProvider);
    final loanBox  = ref.read(loanBoxProvider);
    final stashBox = ref.read(stashBoxProvider);

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type CONFIRM to proceed. This cannot be undone.'),
            const SizedBox(height: 8),
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text == 'CONFIRM'),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (confirmed == true) {
      for (final item in itemBox.values)  { await itemBox.delete(item.id); }
      for (final loan in loanBox.values)  { await loanBox.delete(loan.id); }
      for (final s in stashBox.values)    { await stashBox.delete(s.id); }

      await cancelAllScheduledNotifications();
      Hive.box('settings').put(_kOnboardingSeen, false);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersEnabled  = ref.watch(reminderEnabledProvider);
    final reminderTime      = ref.watch(reminderTimeProvider);
    final showThumbnails    = ref.watch(showThumbnailsProvider);
    final appLockEnabled    = ref.watch(appLockEnabledProvider);
    final themeModeSetting  = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('App Lock (Face/Touch/PIN)'),
            subtitle: const Text('Require auth on cold start and after 2 minutes in the background'),
            value: appLockEnabled,
            onChanged: (v) => ref.read(appLockEnabledProvider.notifier).set(v),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text({
              ThemeModeSetting.system: 'Follow system',
              ThemeModeSetting.light:  'Light',
              ThemeModeSetting.dark:   'Dark',
            }[themeModeSetting]!),
            trailing: DropdownButton<ThemeModeSetting>(
              value: themeModeSetting,
              items: const [
                DropdownMenuItem(value: ThemeModeSetting.system, child: Text('System')),
                DropdownMenuItem(value: ThemeModeSetting.light,  child: Text('Light')),
                DropdownMenuItem(value: ThemeModeSetting.dark,   child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) ref.read(themeModeProvider.notifier).set(mode);
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Reminders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Due-date reminders'),
            subtitle: const Text('Get notified when a loan is due'),
            value: remindersEnabled,
            onChanged: (v) => ref.read(reminderEnabledProvider.notifier).set(context, v),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Reminder time'),
            subtitle: Text('Current: ${reminderTime.format(context)}'),
            enabled: remindersEnabled,
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: reminderTime);
              if (picked != null) {
                await ref.read(reminderTimeProvider.notifier).set(picked);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reminder time set to ${picked.format(context)}')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Show thumbnails on Home'),
            value: showThumbnails,
            onChanged: (v) => ref.read(showThumbnailsProvider.notifier).set(v),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Export All'),
            subtitle: const Text('Share items, loans, stashes (CSV) and a summary PDF'),
            onTap: () => _exportAll(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_done),
            title: const Text('Import All (dry-run)'),
            subtitle: kIsWeb ? const Text('Not available on web') : const Text('Analyze bundle/CSVs without writing'),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _importAll(context, ref, dryRun: true),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import All'),
            subtitle: kIsWeb ? const Text('Not available on web') : const Text('Apply changes from bundle/CSVs'),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _importAll(context, ref, dryRun: false),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Delete All Data'),
            subtitle: const Text('Type CONFIRM to delete all app data'),
            onTap: () => _deleteAll(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.slideshow),
            title: const Text('Show onboarding again'),
            subtitle: const Text('See the welcome slides next launch'),
            onTap: () {
              Hive.box('settings').put(_kOnboardingSeen, false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Onboarding will show on next launch')),
              );
            },
          ),

          // --- About & Support ---
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('About & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About “Where It’s At”'),
            subtitle: const Text('Version, credits, and privacy'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Where It's At",
                applicationVersion: '1.0.0',
                applicationIcon: const CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage('assets/icons/app_icon.png'),
                  backgroundColor: Colors.transparent,
                ),
                children: const [
                  SizedBox(height: 8),
                  Text("Track what you lend and where you stash things."),
                  SizedBox(height: 8),
                  Text("Privacy: all data is stored locally on your device. "
                      "Export/backup is available in Settings → Data."),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact Support'),
            subtitle: const Text('Email us with feedback or issues'),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'support@platovalabs.com',
                queryParameters: {'subject': "Where It's At Support"},
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we handle your data'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PolicyPage(
                  title: 'Privacy Policy',
                  markdown: '''
**Where It’s At** stores data locally on your device.
We do not collect, transmit, or sell personal data.
You control exports/backups (Settings → Data).
''',
                ),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.rule_folder_outlined),
            title: const Text('Terms of Use'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PolicyPage(
                  title: 'Terms of Use',
                  markdown: '''
This app is provided "as is" without warranties.
You’re responsible for your exported backups.
''',
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}
