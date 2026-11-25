import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages data for personal lifestyle habits:
/// 1. Daily 5 Prayers (Fajr, Dhuhr, Asr, Maghrib, Isha)
/// 2. User-defined custom streaks (e.g. No Smoking, Cold Showers, Workout)
/// 3. Custom habits with daily check-ins
/// 4. Daily lifestyle notes / reflections
class HabitStore {
  static const _keyPrayers = 'milos.habits.prayers';
  static const _keyCustomStreaks = 'milos.habits.custom_streaks.v2';
  static const _keyCustomHabits = 'milos.habits.custom';
  static const _keyNotes = 'milos.habits.notes';

  static String _dateKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String todayKey() => _dateKeyFor(DateTime.now());

  // ─── Prayers ─────────────────────────────────────────────────────────────
  static const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const prayerNamesAr = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  static Map<String, int> _decodePrayerMap(String? raw) {
    final empty = {for (var p in prayerNames) p: 0};
    if (raw == null) return empty;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (var p in prayerNames)
          p: switch (decoded[p]) {
            final int v => v < 0 ? 0 : v,
            true => 1, // legacy bool true
            _ => 0,
          },
      };
    } catch (_) {
      return empty;
    }
  }

  /// Returns map of prayer name -> prayer count (times prayed) for given date.
  /// Backwards compatible: old bool values are read as 0/1.
  static Future<Map<String, int>> loadPrayerCounts([String? dateKey]) async {
    final key = dateKey ?? todayKey();
    final prefs = await SharedPreferences.getInstance();
    return _decodePrayerMap(prefs.getString('$_keyPrayers.$key'));
  }

  /// Sums prayer counts across all recorded days, or only the last [lastDays] days.
  static Future<Map<String, int>> loadPrayerTotals({int? lastDays}) async {
    final prefs = await SharedPreferences.getInstance();
    final totals = {for (var p in prayerNames) p: 0};
    Set<String>? allowedKeys;
    if (lastDays != null) {
      final now = DateTime.now();
      allowedKeys = {
        for (var i = 0; i < lastDays; i++)
          '$_keyPrayers.${_dateKeyFor(now.subtract(Duration(days: i)))}',
      };
    }
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('$_keyPrayers.')) continue;
      if (allowedKeys != null && !allowedKeys.contains(k)) continue;
      final dayCounts = _decodePrayerMap(prefs.getString(k));
      for (final p in prayerNames) {
        totals[p] = totals[p]! + (dayCounts[p] ?? 0);
      }
    }
    return totals;
  }

  /// Loads daily prayer counts for the last [days] days (oldest first).
  static Future<List<MapEntry<DateTime, Map<String, int>>>> loadRecentPrayerHistory({
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final raw = prefs.getString('$_keyPrayers.${_dateKeyFor(date)}');
      return MapEntry(date, _decodePrayerMap(raw));
    });
  }

  /// Returns map of prayer name -> bool (prayed ≥ 1 time) for compatibility.
  static Future<Map<String, bool>> loadPrayers([String? dateKey]) async {
    final counts = await loadPrayerCounts(dateKey);
    return counts.map((k, v) => MapEntry(k, v > 0));
  }

  /// Increment count for a specific prayer (tap +).
  static Future<void> incrementPrayer(String prayer, [String? dateKey]) async {
    final key = dateKey ?? todayKey();
    final counts = await loadPrayerCounts(key);
    counts[prayer] = (counts[prayer] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrayers.$key', jsonEncode(counts));
  }

  /// Decrement count for a specific prayer (tap −), floor at 0.
  static Future<void> decrementPrayer(String prayer, [String? dateKey]) async {
    final key = dateKey ?? todayKey();
    final counts = await loadPrayerCounts(key);
    final cur = counts[prayer] ?? 0;
    counts[prayer] = cur > 0 ? cur - 1 : 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrayers.$key', jsonEncode(counts));
  }

  /// Legacy toggle — now increments if 0, decrements if ≥1. Kept for compat.
  static Future<void> togglePrayer(String prayer, [String? dateKey]) async {
    final key = dateKey ?? todayKey();
    final counts = await loadPrayerCounts(key);
    final cur = counts[prayer] ?? 0;
    counts[prayer] = cur == 0 ? 1 : 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrayers.$key', jsonEncode(counts));
  }

  // ─── Custom Streaks (User defined: No Smoking, Cold Shower, etc.) ─────────
  static Future<List<StreakTracker>> loadCustomStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCustomStreaks);
    if (raw == null) {
      // Default initial streaks the user can customize or delete
      return [
        StreakTracker(
          id: 'default_nosmoke',
          titleEn: 'No Smoking',
          titleAr: 'الامتناع عن التدخين',
          startDate: DateTime.now(),
        ),
      ];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => StreakTracker.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCustomStreaks(List<StreakTracker> streaks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyCustomStreaks,
      jsonEncode(streaks.map((s) => s.toJson()).toList()),
    );
  }

  static Future<void> addCustomStreak(String titleEn, String titleAr, [DateTime? startDate]) async {
    final streaks = await loadCustomStreaks();
    streaks.add(StreakTracker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titleEn: titleEn,
      titleAr: titleAr,
      startDate: startDate ?? DateTime.now(),
    ));
    await saveCustomStreaks(streaks);
  }

  static Future<void> resetCustomStreak(String id) async {
    final streaks = await loadCustomStreaks();
    final idx = streaks.indexWhere((s) => s.id == id);
    if (idx != -1) {
      streaks[idx] = streaks[idx].copyWith(lastResetDate: DateTime.now());
      await saveCustomStreaks(streaks);
    }
  }

  static Future<void> deleteCustomStreak(String id) async {
    final streaks = await loadCustomStreaks();
    streaks.removeWhere((s) => s.id == id);
    await saveCustomStreaks(streaks);
  }

  // ─── Custom Habits ───────────────────────────────────────────────────────
  static Future<List<HabitItem>> loadCustomHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCustomHabits);
    if (raw == null) {
      // Default initial habits
      return [
        HabitItem(id: 'read', titleEn: 'Reading Quran / Book', titleAr: 'قراءة القرآن / كتاب'),
        HabitItem(id: 'workout', titleEn: 'Exercise / Walk', titleAr: 'رياضة / مشي'),
        HabitItem(id: 'water', titleEn: 'Drink 2L Water', titleAr: 'شرب ليترين ماء'),
      ];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HabitItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCustomHabits(List<HabitItem> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = habits.map((h) => h.toJson()).toList();
    await prefs.setString(_keyCustomHabits, jsonEncode(jsonList));
  }

  static Future<void> toggleHabitDone(String habitId, [String? dateKey]) async {
    final key = dateKey ?? todayKey();
    final habits = await loadCustomHabits();
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final habit = habits[index];
    final history = Map<String, bool>.from(habit.history);
    final isDone = history[key] == true;
    if (isDone) {
      history.remove(key);
    } else {
      history[key] = true;
    }

    // Recompute streak
    var streak = 0;
    var checkDate = DateTime.now();
    while (true) {
      final ck = '${checkDate.year.toString().padLeft(4, '0')}-'
          '${checkDate.month.toString().padLeft(2, '0')}-'
          '${checkDate.day.toString().padLeft(2, '0')}';
      if (history[ck] == true) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    habits[index] = habit.copyWith(history: history, streak: streak);
    await saveCustomHabits(habits);
  }

  static Future<void> addCustomHabit(String titleEn, String titleAr) async {
    final habits = await loadCustomHabits();
    habits.add(HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titleEn: titleEn,
      titleAr: titleAr,
    ));
    await saveCustomHabits(habits);
  }

  static Future<void> deleteCustomHabit(String id) async {
    final habits = await loadCustomHabits();
    habits.removeWhere((h) => h.id == id);
    await saveCustomHabits(habits);
  }

  // ─── Lifestyle Notes / Reflections ───────────────────────────────────────
  static Future<List<HabitNote>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotes);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => HabitNote.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addNote(String text) async {
    final notes = await loadNotes();
    notes.insert(0, HabitNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      date: DateTime.now(),
    ));
    // Keep max 50 notes to save space
    if (notes.length > 50) notes.removeRange(50, notes.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotes, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  static Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotes, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }
}

class HabitItem {
  const HabitItem({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    this.streak = 0,
    this.history = const {},
  });

  final String id;
  final String titleEn;
  final String titleAr;
  final int streak;
  final Map<String, bool> history;

  bool isDoneToday() => history[HabitStore.todayKey()] == true;

  HabitItem copyWith({
    int? streak,
    Map<String, bool>? history,
  }) => HabitItem(
    id: id,
    titleEn: titleEn,
    titleAr: titleAr,
    streak: streak ?? this.streak,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'streak': streak,
    'history': history,
  };

  factory HabitItem.fromJson(Map<String, dynamic> json) => HabitItem(
    id: json['id'] as String,
    titleEn: json['titleEn'] as String? ?? '',
    titleAr: json['titleAr'] as String? ?? '',
    streak: json['streak'] as int? ?? 0,
    history: (json['history'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as bool),
    ) ?? {},
  );
}

class HabitNote {
  const HabitNote({
    required this.id,
    required this.text,
    required this.date,
  });

  final String id;
  final String text;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'date': date.toIso8601String(),
  };

  factory HabitNote.fromJson(Map<String, dynamic> json) => HabitNote(
    id: json['id'] as String,
    text: json['text'] as String,
    date: DateTime.parse(json['date'] as String),
  );
}

class StreakTracker {
  const StreakTracker({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.startDate,
    this.lastResetDate,
  });

  final String id;
  final String titleEn;
  final String titleAr;
  final DateTime startDate;
  final DateTime? lastResetDate;

  /// Current active days count since start (or last reset)
  int get daysCount {
    final base = lastResetDate ?? startDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseDay = DateTime(base.year, base.month, base.day);
    final diff = today.difference(baseDay).inDays;
    return diff < 0 ? 0 : diff;
  }

  StreakTracker copyWith({
    String? titleEn,
    String? titleAr,
    DateTime? startDate,
    DateTime? lastResetDate,
  }) => StreakTracker(
    id: id,
    titleEn: titleEn ?? this.titleEn,
    titleAr: titleAr ?? this.titleAr,
    startDate: startDate ?? this.startDate,
    lastResetDate: lastResetDate ?? this.lastResetDate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titleEn': titleEn,
    'titleAr': titleAr,
    'startDate': startDate.toIso8601String(),
    if (lastResetDate != null) 'lastResetDate': lastResetDate!.toIso8601String(),
  };

  factory StreakTracker.fromJson(Map<String, dynamic> json) => StreakTracker(
    id: json['id'] as String,
    titleEn: json['titleEn'] as String? ?? '',
    titleAr: json['titleAr'] as String? ?? '',
    startDate: DateTime.parse(json['startDate'] as String),
    lastResetDate: json['lastResetDate'] != null
        ? DateTime.parse(json['lastResetDate'] as String)
        : null,
  );
}
