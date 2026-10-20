import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'task.dart';

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _ready = true;
      return;
    }
    timezone_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localZone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> schedule(Task task) async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Scheduled reminders require the mobile app.');
    }
    final pending = await _plugin.pendingNotificationRequests();
    final slots = task.remindUntil.difference(task.remindAt).inMinutes ~/ 60 + 1;
    if (pending.length + slots > 60) {
      throw StateError('There are too many scheduled reminders.');
    }

    var scheduled = 0;
    try {
      for (var at = task.remindAt;
          !at.isAfter(task.remindUntil);
          at = at.add(const Duration(hours: 1))) {
        if (at.isAfter(DateTime.now())) {
          await _plugin.zonedSchedule(
            id: task.id * 100 + scheduled,
            title: 'A little reminder',
            body: task.title,
            scheduledDate: timezone.TZDateTime.from(at, timezone.local),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'milos_task_reminders',
                'Task reminders',
                channelDescription: 'Reminders for your tasks',
                icon: 'milos_notification_small',
                largeIcon: DrawableResourceAndroidBitmap(
                  'milos_notification_logo',
                ),
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: task.id.toString(),
          );
          scheduled++;
        }
      }
    } catch (_) {
      await cancel(task);
      rethrow;
    }
  }

  Future<void> cancel(Task task) async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final slots = task.remindUntil.difference(task.remindAt).inMinutes ~/ 60 + 1;
    for (var index = 0; index < slots; index++) {
      await _plugin.cancel(id: task.id * 100 + index);
    }
  }
}
