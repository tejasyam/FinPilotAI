import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../data/models/finance_models.dart';

abstract interface class BillNotificationService {
  bool get supported;
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule(BillReminder bill);
  Future<void> cancel(BillReminder bill);
  Future<void> cancelAll();
}

class PlatformBillNotificationService implements BillNotificationService {
  PlatformBillNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (!supported || _initialized) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> schedule(BillReminder bill) async {
    if (!supported) return;
    await initialize();
    final due = bill.dueDate.toLocal();
    final scheduled = tz.TZDateTime(tz.local, due.year, due.month, due.day, 9);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      await cancel(bill);
      return;
    }
    await _plugin.zonedSchedule(
      id: notificationIdFor(bill.id),
      title: 'Bill due today: ${bill.title}',
      body:
          '₹${bill.amountPaise ~/ 100}.${(bill.amountPaise % 100).toString().padLeft(2, '0')} is due today.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'finpilot_bill_reminders',
          'Bill reminders',
          channelDescription: 'Reminders for locally saved bills.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: bill.id,
    );
  }

  @override
  Future<void> cancel(BillReminder bill) async {
    if (!supported) return;
    await initialize();
    await _plugin.cancel(id: notificationIdFor(bill.id));
  }

  @override
  Future<void> cancelAll() async {
    if (!supported) return;
    await initialize();
    await _plugin.cancelAll();
  }

  /// Stable, non-negative 31-bit ID used for every schedule/update/cancel call.
  static int notificationIdFor(String billId) {
    var hash = 0x811c9dc5;
    for (final unit in billId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
