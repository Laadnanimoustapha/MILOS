import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

// ---------------------------------------------------------------------------
// AI chat service – proxies requests through the MILOS Rust server and caches
// admin-assigned models + icons locally so icons load once until changed.
// ---------------------------------------------------------------------------

/// Fallback AI models used before the first server sync completes.
const groqModels = <String, String>{
  'openai/gpt-oss-20b': 'GPT-OSS 20B (fast)',
  'openai/gpt-oss-120b': 'GPT-OSS 120B',
  'qwen/qwen3.8-27b': 'Qwen 3.8 27B',
  'allam-2-7b': 'ALLaM 2 7B (Arabic)',
};

const defaultGroqModel = 'openai/gpt-oss-20b';

class AiModelInfo {
  AiModelInfo({
    required this.id,
    required this.name,
    this.provider = 'groq',
    this.icon = '',
  });

  final String id;
  final String name;
  final String provider;
  final String icon;
  Uint8List? _cachedBytes;
  bool _decoded = false;

  /// Decodes base64 PNG/WebP/JPG data URLs once and caches bytes in memory.
  Uint8List? get iconBytes {
    if (_decoded) return _cachedBytes;
    _decoded = true;
    final raw = icon.trim();
    if (raw.isEmpty) return null;
    try {
      final comma = raw.indexOf(',');
      final b64 = (raw.startsWith('data:') && comma != -1)
          ? raw.substring(comma + 1)
          : raw;
      _cachedBytes = base64Decode(b64);
    } catch (_) {
      _cachedBytes = null;
    }
    return _cachedBytes;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'icon': icon,
  };

  factory AiModelInfo.fromJson(Map<String, dynamic> j) => AiModelInfo(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? (j['id'] as String? ?? ''),
    provider: j['provider'] as String? ?? 'groq',
    icon: j['icon'] as String? ?? '',
  );
}

typedef AiModelCatalog = ({
  String? version,
  String defaultModel,
  List<AiModelInfo> models,
});

class AiModelStore {
  static const _cacheKey = 'milos.ai.models.v1';
  static String? lastSyncError;

  static List<AiModelInfo> get fallbackModels => groqModels.entries
      .map((e) => AiModelInfo(id: e.key, name: e.value))
      .toList();

  static Future<AiModelCatalog> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) {
        return (
          version: null,
          defaultModel: defaultGroqModel,
          models: fallbackModels,
        );
      }
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final models = (j['models'] as List? ?? [])
          .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
          .where((m) => m.id.isNotEmpty)
          .toList();
      if (models.isEmpty) {
        return (
          version: null,
          defaultModel: defaultGroqModel,
          models: fallbackModels,
        );
      }
      final def = j['default_model'] as String? ?? models.first.id;
      return (
        version: j['version'] as String?,
        defaultModel: models.any((m) => m.id == def) ? def : models.first.id,
        models: models,
      );
    } catch (_) {
      return (
        version: null,
        defaultModel: defaultGroqModel,
        models: fallbackModels,
      );
    }
  }

  /// Checks server for model/icon updates using cached version hash.
  /// Only downloads & writes to local storage when the server version changed.
  static Future<AiModelCatalog> syncModels() async {
    final cached = await loadCached();
    lastSyncError = null;
    try {
      final res = await ApiClient.fetchAiModels(currentVersion: cached.version);
      if (res['unchanged'] == true) return cached;

      final models = (res['models'] as List? ?? [])
          .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
          .where((m) => m.id.isNotEmpty)
          .toList();
      if (models.isEmpty) return cached;

      final version = res['version'] as String?;
      final rawDef = res['default_model'] as String? ?? models.first.id;
      final def = models.any((m) => m.id == rawDef) ? rawDef : models.first.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'version': version,
          'default_model': def,
          'models': models.map((m) => m.toJson()).toList(),
        }),
      );
      return (version: version, defaultModel: def, models: models);
    } catch (e) {
      lastSyncError = '$e';
      return cached;
    }
  }
}

Future<String> groqChat({
  required String model,
  required List<Map<String, String>> messages,
  String? currentDatetime,
  List<String> memories = const [],
}) async {
  try {
    return await ApiClient.aiChat(
      model: model,
      messages: messages,
      currentDatetime: currentDatetime,
      memories: memories,
    );
  } on ApiException catch (e) {
    throw GroqException(e.message);
  }
}

class GroqException implements Exception {
  const GroqException(this.message);
  final String message;
  @override
  String toString() => message;
}
