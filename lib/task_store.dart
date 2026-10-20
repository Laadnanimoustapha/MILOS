import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task.dart';

class TaskStore {
  static const _key = 'milos.tasks.v1';
  static const _backupKey = 'milos.tasks.v1.backup';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<Task>> load() async {
    final value = await _preferences.getString(_key);
    if (value == null) {
      final backup = await _preferences.getString(_backupKey);
      if (backup == null) return [];
      final tasks = _decode(backup);
      await _preferences.setString(_key, backup);
      return tasks;
    }
    try {
      return _decode(value);
    } catch (_) {
      final backup = await _preferences.getString(_backupKey);
      if (backup == null) rethrow;
      final tasks = _decode(backup);
      await _preferences.setString(_key, backup);
      return tasks;
    }
  }

  Future<void> save(List<Task> tasks) async {
    final value = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await _preferences.setString(_key, value);
    await _preferences.setString(_backupKey, value);
  }

  List<Task> _decode(String value) {
    final items = jsonDecode(value) as List<dynamic>;
    return items
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
