import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import '../domain/loan.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications(BuildContext? context) async {
  if (kIsWeb) return; // no-op on web
  tzdata.initializeTimeZones();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {
      final payload = details.payload;
      if (payload != null && context != null) {
        Navigator.of(context).pushNamed('/itemDetail', arguments: payload);
        // TODO: highlight loan card in ItemDetailScreen
      }
    },
  );
}

Future<bool> requestNotificationPermission() async {
  // Android 13+ POST_NOTIFICATIONS; on older Android, this returns granted.
  final status = await Permission.notification.request();
  return status.isGranted;
}

Future<void> scheduleLoanNotification({
  required String loanId,
  required String itemName,
  required DateTime dueDate,
  required TimeOfDay reminderTime,
  bool oneDayBefore = false,
}) async {
  final tzDue = tz.TZDateTime.local(dueDate.year, dueDate.month, dueDate.day, reminderTime.hour, reminderTime.minute);
  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      loanId.hashCode,
      'Loan Due: $itemName',
      'Due today for $itemName',
      tzDue,
      const NotificationDetails(
        android: AndroidNotificationDetails('loan_due', 'Loan Due', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: loanId,
      matchDateTimeComponents: null,
    );
    if (oneDayBefore) {
      final tzBefore = tzDue.subtract(const Duration(days: 1));
      await flutterLocalNotificationsPlugin.zonedSchedule(
        loanId.hashCode + 1,
        'Loan Due Soon: $itemName',
        'Due tomorrow for $itemName',
        tzBefore,
        const NotificationDetails(
          android: AndroidNotificationDetails('loan_due', 'Loan Due', importance: Importance.max, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: loanId,
        matchDateTimeComponents: null,
      );
    }
  } catch (e) {
    debugPrint('Notification scheduling failed: $e');
  }
}

Future<void> cancelLoanNotification(String loanId) async {
  await flutterLocalNotificationsPlugin.cancel(loanId.hashCode);
  await flutterLocalNotificationsPlugin.cancel(loanId.hashCode + 1);
}

Future<void> cancelAllScheduledNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
}

Future<void> rescheduleAllDueNotifications() async {
  // Reschedule all future loan notifications based on current settings
  final box = Hive.box<Loan>('loans');
  final settings = Hive.box('settings');
  final remindersEnabled = settings.get('remindersEnabled', defaultValue: true) as bool;
  final hour = settings.get('reminderHour', defaultValue: 9) as int;
  final minute = settings.get('reminderMinute', defaultValue: 0) as int;
  final reminderTime = TimeOfDay(hour: hour, minute: minute);
  if (!remindersEnabled) {
    await cancelAllScheduledNotifications();
    return;
  }
  await cancelAllScheduledNotifications();
  for (final loan in box.values) {
    if (loan.status == LoanStatus.out && loan.dueOn != null) {
      await scheduleLoanNotification(
        loanId: loan.id,
        itemName: loan.itemId, // If you want item name, pass it in
        dueDate: loan.dueOn!,
        reminderTime: reminderTime,
        oneDayBefore: true,
      );
    }
  }
}
