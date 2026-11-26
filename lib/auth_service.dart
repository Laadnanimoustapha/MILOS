import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists JWT auth session and server URL in SharedPreferences.
class AuthStore {
  static const _keyToken = 'milos.auth.token';
  static const _keyEmail = 'milos.auth.email';
  static const _keyServerUrl = 'milos.server.url';

  static const defaultServerUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static Future<({String? token, String? email})> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final email = prefs.getString(_keyEmail);
    if (token == null || token.isEmpty) return (token: null, email: null);
    return (token: token, email: email);
  }

  static Future<void> saveSession(String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyEmail, email);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
  }

  static Future<String> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyServerUrl)?.trim();
    if (saved != null && saved.isNotEmpty) return _stripTrailingSlash(saved);
    return _stripTrailingSlash(defaultServerUrl);
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = _stripTrailingSlash(url.trim());
    if (clean.isEmpty) {
      await prefs.remove(_keyServerUrl);
    } else {
      await prefs.setString(_keyServerUrl, clean);
    }
  }

  static String _stripTrailingSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Minimal Dart-only HTTP client for the MILOS Rust backend.
class ApiClient {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _request(
      'POST',
      '/api/auth/login',
      body: {'email': email.trim(), 'password': password},
      requireAuth: false,
    );
    final token = res['token'] as String? ?? '';
    final userEmail = res['email'] as String? ?? email.trim();
    if (token.isEmpty) throw const ApiException('Server returned empty token.');
    await AuthStore.saveSession(token, userEmail);
    return res;
  }

  static Future<void> syncBackup(Map<String, dynamic> payload) async {
    await _request('POST', '/api/backup/sync', body: payload);
  }

  static Future<Map<String, dynamic>> restoreBackup() =>
      _request('GET', '/api/backup/restore');

  static Future<void> clearBackup() async {
    await _request('DELETE', '/api/backup/clear');
  }

  static Future<String> aiChat({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final res = await _request(
      'POST',
      '/api/ai/chat',
      body: {'model': model, 'messages': messages},
      timeoutSeconds: 30,
    );
    return (res['content'] as String? ?? '').trim();
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    int timeoutSeconds = 15,
  }) async {
    if (kIsWeb) {
      throw const ApiException('Backend sync requires mobile or desktop.');
    }

    String? token;
    if (requireAuth) {
      token = (await AuthStore.loadSession()).token;
      if (token == null || token.isEmpty) {
        throw const ApiException('Not signed in.', statusCode: 401);
      }
    }

    final baseUrl = await AuthStore.loadServerUrl();
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSeconds);

    try {
      final req = await client.openUrl(method, uri);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.contentLength = bytes.length;
        req.add(bytes);
      }

      final res = await req.close().timeout(Duration(seconds: timeoutSeconds));
      final raw = await res.transform(utf8.decoder).join();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(
          _extractError(raw, res.statusCode),
          statusCode: res.statusCode,
        );
      }
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } on SocketException catch (e) {
      throw ApiException('Connection error: ${e.message}');
    } on TimeoutException {
      throw const ApiException('Server request timed out.');
    } finally {
      client.close();
    }
  }

  static String _extractError(String body, int status) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {}
    return body.isNotEmpty ? body : 'Server error ($status)';
  }
}
