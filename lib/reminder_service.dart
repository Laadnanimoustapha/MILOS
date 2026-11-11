import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'task.dart';

import 'task_store.dart';

// ─── Custom distinctive vibration pattern (tap-tap... tap) ──────────────────
// Distinct from Android's default buzz: 0ms wait, 120ms tap, 100ms pause,
// 120ms tap, 250ms pause, 350ms hold.
final _milosVibrationPattern = Int64List.fromList([0, 120, 100, 120, 250, 350]);

// ─── Notification action IDs ─────────────────────────────────────────────────
const _actionDone = 'done';
const _actionWait = 'wait';
const _actionStart = 'start';

// ─── Snooze duration used by "Wait" action ───────────────────────────────────
const _snoozeDuration = Duration(minutes: 15);

// ─── Background isolate entry-point ──────────────────────────────────────────
// Called by the OS when the user taps an action while the app is killed/closed.
// IMPORTANT: runs in a NEW isolate — no Flutter engine running.
// Must call WidgetsFlutterBinding.ensureInitialized() before any plugin use.
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) async {
  // Required: initialise Flutter bindings in the background isolate.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise the notification plugin so it can schedule the snooze.
  await ReminderService.instance.initialize();
  _handleResponse(response);
}

void _handleResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;

  final parts = payload.split(':');
  final taskId = int.tryParse(parts[0]);
  if (taskId == null) return;

  if (response.actionId == _actionDone) {
    _markTaskDone(taskId);
  } else if (response.actionId == _actionWait) {
    _snoozeTask(taskId);
  } else if (response.actionId == _actionStart) {
    _startTask(taskId);
  }
}

Future<void> _markTaskDone(int taskId) async {
  try {
    final store = TaskStore();
    final tasks = await store.load();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = tasks[index];
    tasks[index] = task.copyWith(done: true, inProgress: false);

    // If the task repeats, spawn the next occurrence for tomorrow / next month etc.
    if (task.repeat != TaskRepeat.none) {
      final nextId = tasks.isEmpty
          ? 1
          : tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
      tasks.add(task.nextRecurrence(nextId));
    }

    await store.save(tasks);
    // Cancel all scheduled notifications for this task; refresh the rest.
    await ReminderService.instance.cancel(task);
    await ReminderService.instance.refresh(tasks);
  } catch (_) {}
}

Future<void> _startTask(int taskId) async {
  try {
    final store = TaskStore();
    final tasks = await store.load();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = tasks[index];
    if (task.done) return;
    // Mark inProgress = true and re-schedule so intermediate alerts stop.
    tasks[index] = task.copyWith(inProgress: true);
    await store.save(tasks);
    await ReminderService.instance.refresh(tasks);
  } catch (_) {}
}

Future<void> _snoozeTask(int taskId) async {
  try {
    final store = TaskStore();
    final tasks = await store.load();
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('not found'),
    );
    if (task.done) return;
    await ReminderService.instance._scheduleSnooze(task);
  } catch (_) {}
}

// ─── Service ─────────────────────────────────────────────────────────────────

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  // Mutable foreground callback — updated from TodayPage without re-init.
  void Function(NotificationResponse)? _onForegroundResponse;

  // ID range for snooze notifications (outside the task.id*100 range).
  // We use 900000 + taskId so it doesn't collide with normal reminders.
  int _snoozeId(int taskId) => 900000 + taskId;

  /// Initialises the plugin (only once) and optionally registers/updates the
  /// foreground action callback.  Safe to call multiple times.
  Future<void> initialize({
    void Function(NotificationResponse)? onForegroundResponse,
  }) async {
    // Always store the latest callback even when already initialized.
    if (onForegroundResponse != null) {
      _onForegroundResponse = onForegroundResponse;
    }
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
      onDidReceiveNotificationResponse: (response) {
        // Use the stored callback so it can be updated after first init.
        _onForegroundResponse?.call(response);
        _handleResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
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
        await _scheduleOne(task, reminders[index], index, isLast: index == reminders.length - 1);
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
        // If task is in progress, skip repeating intermediate alerts and only
        // schedule the final end reminder ("Have you finished?").
        if (task.inProgress) {
          if (end.isAfter(now) && reminders.length < limit) {
            reminders.add(end);
          }
          break;
        }

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
      final next = task.nextOccurrence(occurrence);
      if (!next.isAfter(occurrence)) break;
      occurrence = next;
    }
    return reminders;
  }



  /// Builds the notification body and title for a given reminder index.
  /// When task.inProgress is true or it's the last check-in, asks if finished.
  /// For step tasks each reminder maps to a step until the last one.
  ({String title, String body, bool isFinalCheck}) _notifContent(
    Task task,
    int index, {
    required bool isLast,
  }) {
    if (task.inProgress || isLast) {
      return (
        title: task.title,
        body: 'Have you finished this task?',
        isFinalCheck: true,
      );
    }

    if (task.steps.isEmpty) {
      return (
        title: 'Time for your task!',
        body: task.title,
        isFinalCheck: false,
      );
    }

    // Step-by-step task
    final stepIndex = index % (task.steps.length + 1);
    if (stepIndex < task.steps.length) {
      return (
        title: 'Step ${stepIndex + 1} of ${task.steps.length}: ${task.title}',
        body: task.steps[stepIndex],
        isFinalCheck: false,
      );
    } else {
      return (
        title: task.title,
        body: 'Have you finished this task?',
        isFinalCheck: true,
      );
    }
  }

  Future<void> _scheduleOne(
    Task task,
    DateTime at,
    int index, {
    required bool isLast,
  }) {
    final content = _notifContent(task, index, isLast: isLast);
    final payload = '${task.id}:$index';

    // Action buttons:
    // If it's the final check or the task is in progress: [Done, Wait]
    // If the task has not started yet and is in a time range: [Done, Wait, I start doing it]
    final actions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        _actionDone,
        'Done',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        _actionWait,
        'Wait 15 min',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      if (!task.inProgress &&
          !content.isFinalCheck &&
          task.scheduleMode == TaskScheduleMode.range)
        const AndroidNotificationAction(
          _actionStart,
          'I started doing it',
          showsUserInterface: false,
          cancelNotification: true,
        ),
    ];

    return _plugin.zonedSchedule(
      id: task.id * 100 + index,
      title: content.title,
      body: content.body,
      scheduledDate: timezone.TZDateTime.from(at, timezone.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'milos_task_reminders_v2',
          'Task reminders',
          channelDescription: 'Reminders for your tasks',
          icon: 'milos_notification_small',
          largeIcon: const DrawableResourceAndroidBitmap('milos_notification_logo'),
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: _milosVibrationPattern,
          fullScreenIntent: false,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: 'task_actions',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Schedules an immediate snooze notification (+15 min) outside the normal
  /// reminder window, using a separate ID so it doesn't disrupt the schedule.
  Future<void> _scheduleSnooze(Task task) async {
    final at = DateTime.now().add(_snoozeDuration);
    final tzAt = timezone.TZDateTime.from(at, timezone.local);
    await _plugin.zonedSchedule(
      id: _snoozeId(task.id),
      title: 'Still waiting on you…',
      body: task.title,
      scheduledDate: tzAt,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'milos_task_reminders_v2',
          'Task reminders',
          channelDescription: 'Reminders for your tasks',
          icon: 'milos_notification_small',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: _milosVibrationPattern,
          actions: [
            AndroidNotificationAction(
              _actionDone,
              '✅ Done',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionWait,
              '⏰ Wait 15 min',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: 'task_actions',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '${task.id}:snooze',
    );
  }

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
    await _plugin.cancel(id: _snoozeId(task.id));
  }
}
