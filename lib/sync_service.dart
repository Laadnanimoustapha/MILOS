import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'memory_store.dart';
import 'reminder_service.dart';
import 'task.dart';
import 'task_store.dart';

/// Handles cloud backup sync, empty-local restore, and full data clearing.
/// Local SharedPreferences remains the primary runtime store for tasks,
/// archive, notifications, and progress.
class SyncService {
  static const _kStreakCount = 'milos.streak.count';
  static const _kStreakLastDate = 'milos.streak.last_date';
  static const _kWeekHistory = 'milos.week.history';
  static const _kPrayersPrefix = 'milos.habits.prayers.';
  static const _kCustomStreaks = 'milos.habits.custom_streaks.v2';
  static const _kCustomHabits = 'milos.habits.custom';
  static const _kNotes = 'milos.habits.notes';
  static const _kChatSessions = 'milos.chat.sessions.v1';

  /// Sends current local tasks (including archive) and progress to the server.
  /// Silent on network failures so offline usage is never blocked.
  static Future<void> syncNow() async {
    try {
      final session = await AuthStore.loadSession();
      if (session.token == null) return;

      final tasks = await TaskStore().load();
      final prefs = await SharedPreferences.getInstance();
      final memories = await MemoryStore().load();

      final prayersByDay = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_kPrayersPrefix)) {
          final raw = prefs.getString(key);
          if (raw != null) {
            try {
              prayersByDay[key.substring(_kPrayersPrefix.length)] = jsonDecode(raw);
            } catch (_) {}
          }
        }
      }

      dynamic decodeOpt(String key) {
        final raw = prefs.getString(key);
        if (raw == null) return null;
        try {
          return jsonDecode(raw);
        } catch (_) {
          return null;
        }
      }

      final payload = <String, dynamic>{
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'progress': {
          'streakCount': prefs.getInt(_kStreakCount) ?? 0,
          'streakLastDate': prefs.getString(_kStreakLastDate) ?? '',
          'weekHistory': decodeOpt(_kWeekHistory) ?? <String, dynamic>{},
          'prayersByDay': prayersByDay,
          'customStreaks': decodeOpt(_kCustomStreaks),
          'customHabits': decodeOpt(_kCustomHabits),
          'notes': decodeOpt(_kNotes),
          'memories': memories,
        },
      };

      await ApiClient.syncBackup(payload);
    } catch (_) {
      // Offline / transient failures are ignored; local storage stays authoritative.
    }
  }

  /// Checks if local tasks are empty; if so, restores tasks & progress from server.
  /// Returns true if data was restored.
  static Future<bool> restoreIfLocalEmpty() async {
    try {
      final session = await AuthStore.loadSession();
      if (session.token == null) return false;

      final store = TaskStore();
      final localTasks = await store.load();
      if (localTasks.isNotEmpty) return false;

      final backup = await ApiClient.restoreBackup();
      final rawTasks = (backup['tasks'] as List<dynamic>?) ?? const [];
      final progress = backup['progress'] as Map<String, dynamic>? ?? const {};

      final restoredTasks = <Task>[];
      for (final item in rawTasks) {
        if (item is Map<String, dynamic>) {
          try {
            restoredTasks.add(Task.fromJson(item));
          } catch (_) {}
        }
      }

      if (restoredTasks.isEmpty && progress.isEmpty) return false;

      if (restoredTasks.isNotEmpty) {
        await store.save(restoredTasks);
      }

      final prefs = await SharedPreferences.getInstance();
      final streakCount = progress['streakCount'];
      if (streakCount is int) await prefs.setInt(_kStreakCount, streakCount);
      final streakLastDate = progress['streakLastDate'];
      if (streakLastDate is String && streakLastDate.isNotEmpty) {
        await prefs.setString(_kStreakLastDate, streakLastDate);
      }
      final weekHistory = progress['weekHistory'];
      if (weekHistory is Map && weekHistory.isNotEmpty) {
        await prefs.setString(_kWeekHistory, jsonEncode(weekHistory));
      }
      final prayersByDay = progress['prayersByDay'];
      if (prayersByDay is Map) {
        for (final entry in prayersByDay.entries) {
          await prefs.setString(
            '$_kPrayersPrefix${entry.key}',
            jsonEncode(entry.value),
          );
        }
      }
      if (progress['customStreaks'] != null) {
        await prefs.setString(_kCustomStreaks, jsonEncode(progress['customStreaks']));
      }
      if (progress['customHabits'] != null) {
        await prefs.setString(_kCustomHabits, jsonEncode(progress['customHabits']));
      }
      if (progress['notes'] != null) {
        await prefs.setString(_kNotes, jsonEncode(progress['notes']));
      }
      final memories = progress['memories'];
      if (memories is List) {
        await MemoryStore().save(memories.whereType<String>().toList());
      }

      return restoredTasks.isNotEmpty || progress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Deletes backup from MongoDB and clears all local tasks, archive,
  /// progress, habits, memories, chat sessions, and scheduled notifications.
  static Future<void> clearAllData() async {
    await ApiClient.clearBackup();

    await TaskStore().save(const []);
    await MemoryStore().clear();

    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = <String>[
      _kStreakCount,
      _kStreakLastDate,
      _kWeekHistory,
      _kCustomStreaks,
      _kCustomHabits,
      _kNotes,
      _kChatSessions,
      ...prefs.getKeys().where((k) => k.startsWith(_kPrayersPrefix)),
    ];
    for (final k in keysToRemove) {
      await prefs.remove(k);
    }

    try {
      await ReminderService.instance.refresh(const []);
    } catch (_) {}
  }
}
