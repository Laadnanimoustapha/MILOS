import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// MemoryStore — persists a list of plain-text memory strings.
// Each string is one fact Milos has learned about the user.
// Storage: shared_preferences key 'milos.memory.v1' as JSON array of strings.
// Zero external deps — Dart-only.
// ---------------------------------------------------------------------------
class MemoryStore {
  static const _key = 'milos.memory.v1';
  final _prefs = SharedPreferencesAsync();

  Future<List<String>> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<String> memories) async {
    final clean = memories.map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
    await _prefs.setString(_key, jsonEncode(clean));
  }

  /// Adds a single new memory if it is not already present (case-insensitive).
  /// Returns the updated list.
  Future<List<String>> add(String memory) async {
    final current = await load();
    final norm = memory.trim().toLowerCase();
    if (current.any((m) => m.toLowerCase() == norm)) return current;
    // Keep at most 50 memories to avoid bloating the system prompt.
    final updated = [...current, memory.trim()];
    if (updated.length > 50) updated.removeAt(0); // drop oldest
    await save(updated);
    return updated;
  }

  Future<void> delete(int index) async {
    final current = await load();
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    await save(current);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

