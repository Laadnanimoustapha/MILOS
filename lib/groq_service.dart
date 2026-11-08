import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Groq API service – Dart-only, no extra dependencies.
// Uses dart:io HttpClient to stay dep-free.
// API keys with round-robin fallback. Keys are stored in shared_preferences.
// ---------------------------------------------------------------------------

const _groqEndpoint = 'api.groq.com';
const _groqPath = '/openai/v1/chat/completions';

/// Available Groq models the user can choose from.
const groqModels = <String, String>{
  'llama-3.3-70b-versatile': 'Llama 3.3 70B',
  'llama-3.1-8b-instant': 'Llama 3.1 8B (fast)',
  'mixtral-8x7b-32768': 'Mixtral 8x7B',
  'gemma2-9b-it': 'Gemma 2 9B',
};

const defaultGroqModel = 'llama-3.3-70b-versatile';

// ---------------------------------------------------------------------------
// Key storage – keys live only in shared_preferences, never in source code.
// ---------------------------------------------------------------------------
class GroqKeyStore {
  static const _keys = 'milos.groq.keys.v1';
  static const _k0 = 'milos.groq.key0';
  static const _k1 = 'milos.groq.key1';
  static const _k2 = 'milos.groq.key2';

  static Future<void> save(List<String> keys) async {
    final p = SharedPreferencesAsync();
    await p.setString(_keys, jsonEncode(_clean(keys)));
  }

  static Future<List<String>> load() async {
    try {
      final p = SharedPreferencesAsync();
      final raw = await p.getString(_keys);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return _clean(decoded.whereType<String>());
        } catch (_) {}
      }
      return _clean([
        await p.getString(_k0) ?? '',
        await p.getString(_k1) ?? '',
        await p.getString(_k2) ?? '',
      ]);
    } catch (_) {
      return [];
    }
  }

  static List<String> _clean(Iterable<String> values) {
    final keys = <String>[];
    for (final value in values) {
      final key = value.trim();
      if (key.isNotEmpty && !keys.contains(key)) keys.add(key);
    }
    return keys;
  }

  static Future<bool> get hasKeys async {
    final keys = await load();
    return keys.any((k) => k.isNotEmpty);
  }
}

// Round-robin key index (simple in-memory, fine for single session).
int _keyIndex = 0;

Future<String> groqChat({
  required String model,
  required List<Map<String, String>> messages,
}) async {
  final keys = (await GroqKeyStore.load()).where((k) => k.isNotEmpty).toList();
  if (keys.isEmpty) {
    throw const GroqException('No API keys configured. Add them in Settings.');
  }

  GroqException? lastError;
  var allRateLimited = true;
  for (var attempt = 0; attempt < keys.length; attempt++) {
    final index = _keyIndex % keys.length;
    try {
      final result = await _doRequest(
        key: keys[index],
        model: model,
        messages: messages,
      );
      if (!result.rateLimited) return result.content;
    } on GroqException catch (error) {
      allRateLimited = false;
      lastError = error;
    }
    _keyIndex = (index + 1) % keys.length;
  }
  if (allRateLimited) {
    throw const GroqException('All API keys are rate-limited. Please wait a moment.');
  }
  throw lastError ?? const GroqException('All API keys failed. Please try again.');
}

class _GroqResult {
  const _GroqResult({required this.content, required this.rateLimited});
  final String content;
  final bool rateLimited;
}

Future<_GroqResult> _doRequest({
  required String key,
  required String model,
  required List<Map<String, String>> messages,
}) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.postUrl(
      Uri(scheme: 'https', host: _groqEndpoint, path: _groqPath),
    );
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    request.write(jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.4,
      'max_tokens': 2048,
    }));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 429) {
      return const _GroqResult(content: '', rateLimited: true);
    }
    if (response.statusCode != 200) {
      throw GroqException('Groq error ${response.statusCode}: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final content =
        ((json['choices'] as List).first['message']['content'] as String)
            .trim();
    return _GroqResult(content: content, rateLimited: false);
  } on SocketException catch (e) {
    throw GroqException('Network error: ${e.message}');
  } on TimeoutException {
    throw const GroqException('Request timed out. Check your connection.');
  } finally {
    client.close();
  }
}

class GroqException implements Exception {
  const GroqException(this.message);
  final String message;
  @override
  String toString() => message;
}
