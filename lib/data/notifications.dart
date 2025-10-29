import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/material.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {
      // TODO: Deep-link to item/loan using details.payload
    },
  );
}

Future<void> requestNotificationPermission() async {
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestPermission();
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
}

Future<void> scheduleLoanNotification({
  required String loanId,
  required String itemName,
  required DateTime dueDate,
  required TimeOfDay reminderTime,
  bool oneDayBefore = false,
}) async {
  final tzDue = tz.TZDateTime.local(dueDate.year, dueDate.month, dueDate.day, reminderTime.hour, reminderTime.minute);
  await flutterLocalNotificationsPlugin.zonedSchedule(
    loanId.hashCode,
    'Loan Due: $itemName',
    'Due today for $itemName',
    tzDue,
    const NotificationDetails(
      android: AndroidNotificationDetails('loan_due', 'Loan Due', importance: Importance.max, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    payload: loanId,
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
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: loanId,
    );
  }
}

Future<void> cancelLoanNotification(String loanId) async {
  await flutterLocalNotificationsPlugin.cancel(loanId.hashCode);
  await flutterLocalNotificationsPlugin.cancel(loanId.hashCode + 1);
}
