import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Groq API service – Dart-only, no extra dependencies.
// Uses dart:io HttpClient to stay dep-free.
// Three API keys with round-robin fallback on rate-limit (429).
// Keys are stored in shared_preferences (set once via GroqKeyStore).
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
  static const _k0 = 'milos.groq.key0';
  static const _k1 = 'milos.groq.key1';
  static const _k2 = 'milos.groq.key2';

  static Future<void> save(String k0, String k1, String k2) async {
    final p = SharedPreferencesAsync();
    await p.setString(_k0, k0);
    await p.setString(_k1, k1);
    await p.setString(_k2, k2);
  }

  static Future<List<String>> load() async {
    final p = SharedPreferencesAsync();
    return [
      await p.getString(_k0) ?? '',
      await p.getString(_k1) ?? '',
      await p.getString(_k2) ?? '',
    ];
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

  // Try each key in order; advance index on rate-limit.
  for (var attempt = 0; attempt < keys.length; attempt++) {
    final key = keys[_keyIndex % keys.length];
    final result = await _doRequest(key: key, model: model, messages: messages);
    if (result.rateLimited) {
      _keyIndex = (_keyIndex + 1) % keys.length;
      continue;
    }
    return result.content;
  }
  throw const GroqException('All API keys are rate-limited. Please wait a moment.');
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

