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

  Future<void> schedule(Task task, {int limit = 60}) async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Scheduled reminders require the mobile app.');
    }
    final pending = await _plugin.pendingNotificationRequests();
    final reminders = _upcomingReminders(task, DateTime.now(), limit);
    if (pending.length + reminders.length > 60) {
      throw StateError('There are too many scheduled reminders.');
    }
    try {
      for (var index = 0; index < reminders.length; index++) {
        await _scheduleOne(task, reminders[index], index);
      }
    } catch (_) {
      await cancel(task);
      rethrow;
    }
  }

  Future<void> refresh(List<Task> tasks) async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final pending = await _plugin.pendingNotificationRequests();
    final now = DateTime.now();
    final active = tasks
        .where(
          (task) =>
              !task.done &&
              (task.repeat != TaskRepeat.none || task.remindUntil.isAfter(now)),
        )
        .toList();
    bool belongsToTask(int id) => tasks.any(
      (task) => id >= task.id * 100 && id < task.id * 100 + 60,
    );
    final managed = pending.where((request) => belongsToTask(request.id)).toList();
    for (final request in managed) {
      await _plugin.cancel(id: request.id);
    }
    if (active.isEmpty) return;

    final freeSlots = (60 - pending.length + managed.length)
        .clamp(0, 60)
        .toInt();
    final perTask = freeSlots ~/ active.length;
    final extraSlots = freeSlots % active.length;
    for (var index = 0; index < active.length; index++) {
      final limit = perTask + (index < extraSlots ? 1 : 0);
      if (limit > 0) await schedule(active[index], limit: limit);
    }
  }

  List<DateTime> _upcomingReminders(Task task, DateTime now, int limit) {
    final reminders = <DateTime>[];
    var occurrence = DateTime(
      task.remindAt.year,
      task.remindAt.month,
      task.remindAt.day,
    );
    while (reminders.length < limit) {
      final start = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        task.remindAt.hour,
        task.remindAt.minute,
      );
      if (task.scheduleMode == TaskScheduleMode.fixed) {
        if (start.isAfter(now)) reminders.add(start);
      } else {
        final end = DateTime(
          occurrence.year,
          occurrence.month,
          occurrence.day,
          task.remindUntil.hour,
          task.remindUntil.minute,
        );
        final interval = Duration(minutes: task.reminderIntervalMinutes);
        var at = start;
        while (!at.isAfter(end) && reminders.length < limit) {
          if (at.isAfter(now)) reminders.add(at);
          at = at.add(interval);
        }
        if (end.isAfter(now) &&
            !reminders.contains(end) &&
            start.isBefore(end) &&
            reminders.length < limit) {
          reminders.add(end);
        }
      }
      if (task.repeat == TaskRepeat.none) break;
      final next = _nextOccurrence(occurrence, task);
      if (!next.isAfter(occurrence)) break;
      occurrence = next;
    }
    return reminders;
  }

  DateTime _nextOccurrence(DateTime date, Task task) {
    final unit = switch (task.repeat) {
      TaskRepeat.daily => TaskRepeatUnit.days,
      TaskRepeat.weekly => TaskRepeatUnit.weeks,
      TaskRepeat.monthly => TaskRepeatUnit.months,
      TaskRepeat.custom => task.customRepeatUnit,
      TaskRepeat.none => TaskRepeatUnit.days,
    };
    final every = task.repeat == TaskRepeat.custom
        ? task.customRepeatEvery.clamp(1, 365).toInt()
        : 1;
    if (unit == TaskRepeatUnit.days) return date.add(Duration(days: every));
    if (unit == TaskRepeatUnit.weeks) return date.add(Duration(days: every * 7));
    final monthIndex = date.year * 12 + date.month - 1 + every;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, task.remindAt.day.clamp(1, lastDay).toInt());
  }

  Future<void> _scheduleOne(Task task, DateTime at, int index) =>
      _plugin.zonedSchedule(
        id: task.id * 100 + index,
        title: 'A little reminder',
        body: task.title,
        scheduledDate: timezone.TZDateTime.from(at, timezone.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'milos_task_reminders',
            'Task reminders',
            channelDescription: 'Reminders for your tasks',
            icon: 'milos_notification_small',
            largeIcon: DrawableResourceAndroidBitmap('milos_notification_logo'),
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

  Future<void> cancel(Task task) async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    for (var index = 0; index < 60; index++) {
      await _plugin.cancel(id: task.id * 100 + index);
    }
  }
}
