import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Checks GitHub Releases for a newer version of Milos.
/// Uses only dart:io + dart:convert — zero additional packages.
class UpdateService {
  // ← Replace with your actual GitHub username/repo before releasing
  static const _owner = 'YOUR_GITHUB_USERNAME';
  static const _repo = 'milos';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const _keyLastCheck = 'milos.update.last_check';

  /// Current app version — injected at build time via --dart-define=APP_VERSION=x.y.z
  static const currentVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Checks once per day. Returns [UpdateInfo] if a newer version exists,
  /// null if already up to date, rate-limited, or on any error.
  static Future<UpdateInfo?> checkOncePerDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_keyLastCheck);
      final today = _dateKey();
      if (lastCheck == today) return null; // already checked today
      await prefs.setString(_keyLastCheck, today);
    } catch (_) {
      return null;
    }
    return checkNow();
  }

  /// Forces an immediate check regardless of last-check date.
  static Future<UpdateInfo?> checkNow() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(_apiUrl));
      req.headers
        ..set('Accept', 'application/vnd.github+json')
        ..set('User-Agent', 'milos-app/$currentVersion');
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close(force: true);
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (tag.isEmpty || !_isNewer(tag, currentVersion)) return null;

      // Find arm64 APK download URL
      final assets = (json['assets'] as List<dynamic>?) ?? [];
      final arm64 = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String? ?? '').contains('arm64-v8a'),
        orElse: () => {},
      );
      final downloadUrl =
          arm64['browser_download_url'] as String? ??
          'https://github.com/$_owner/$_repo/releases/latest';

      return UpdateInfo(
        version: tag,
        downloadUrl: downloadUrl,
        releaseNotes: (json['body'] as String? ?? '').trim(),
        releasesUrl: 'https://github.com/$_owner/$_repo/releases/latest',
      );
    } catch (_) {
      return null; // silent fail — never crash for update check
    }
  }

  static String _dateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if [remote] semver is strictly greater than [local].
  static bool _isNewer(String remote, String local) {
    final r = _parse(remote);
    final l = _parse(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String ver) {
    final parts = ver.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasesUrl,
  });
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String releasesUrl;
}
