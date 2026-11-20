import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores streak count + per-day completion history (Mon–Sun of current week)
/// for the progress panel dots and flame badge.
///
/// Keys used (all prefixed `milos.`):
///   milos.streak.count      – int
///   milos.streak.last_date  – "yyyy-MM-dd" string
///   milos.week.history      – JSON map {"yyyy-MM-dd": true, ...}
class StreakStore {
  static const _keyCount = 'milos.streak.count';
  static const _keyLastDate = 'milos.streak.last_date';
  static const _keyHistory = 'milos.week.history';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Returns current streak count (0 if none).
  static Future<int> loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCount) ?? 0;
  }

  /// Returns the 7-day history map {ymd: bool}.
  static Future<Map<String, bool>> loadWeekHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHistory);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  /// Call this when today's last pending task becomes done.
  /// Increments streak if not already credited today.
  /// Returns the new streak count.
  static Future<int> creditToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _ymd(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate) ?? '';

    // Record today in week history
    final raw = prefs.getString(_keyHistory);
    Map<String, bool> history = {};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        history = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
    history[today] = true;
    await prefs.setString(_keyHistory, jsonEncode(history));

    if (lastDate == today) {
      // Already credited today — just return existing count.
      return prefs.getInt(_keyCount) ?? 1;
    }

    // Check if yesterday was credited (streak continuation).
    final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));
    int count = prefs.getInt(_keyCount) ?? 0;
    if (lastDate == yesterday || count == 0) {
      count += 1;
    } else {
      // Streak broken — restart.
      count = 1;
    }

    await prefs.setInt(_keyCount, count);
    await prefs.setString(_keyLastDate, today);
    return count;
  }

  /// Returns booleans for Mon-Sun of the current calendar week.
  /// Index 0 = Monday … index 6 = Sunday.
  static Future<List<bool>> currentWeekDots() async {
    final history = await loadWeekHistory();
    final now = DateTime.now();
    // Monday of this week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return history[_ymd(d)] == true;
    });
  }
}
