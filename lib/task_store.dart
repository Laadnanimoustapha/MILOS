import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task.dart';

class TaskStore {
  static const _key = 'milos.tasks.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<Task>> load() async {
    final value = await _preferences.getString(_key);
    if (value == null) return [];
    final items = jsonDecode(value) as List<dynamic>;
    return items
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Task> tasks) => _preferences.setString(
    _key,
    jsonEncode(tasks.map((task) => task.toJson()).toList()),
  );
}
