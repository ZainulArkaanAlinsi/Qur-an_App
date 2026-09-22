import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/core/app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A published release that is newer than the installed app.
@immutable
class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.url});
  final String version;
  final Uri url;
}

/// Checks GitHub Releases for a newer APK. The app is distributed outside
/// Google Play, so this is how users learn about updates.
class UpdateCheckService {
  UpdateCheckService._();

  static final latestRelease = Uri.https(
    'api.github.com',
    '/repos/ZainulArkaanAlinsi/Qur-an_App/releases/latest',
  );
  static const _checkedKey = 'update_checked_ms';
  static const _interval = Duration(days: 1);

  /// Returns the newest release when it is newer than [appVersion], or null
  /// when up to date, offline, or the response is unusable.
  static Future<AvailableUpdate?> check({http.Client? client}) async {
    final http.Client c = client ?? http.Client();
    try {
      final response = await c
          .get(
            latestRelease,
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = data['tag_name'] as String?;
      final page = data['html_url'] as String?;
      if (tag == null || page == null) return null;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (compareVersions(version, appVersion) <= 0) return null;
      return AvailableUpdate(version: version, url: Uri.parse(page));
    } on Object catch (error) {
      debugPrint('Pemeriksaan pembaruan gagal: $error');
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Like [check], but at most once per day (used on app start).
  static Future<AvailableUpdate?> checkDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_checkedKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < _interval.inMilliseconds) return null;
    await prefs.setInt(_checkedKey, now);
    return check();
  }
}

/// Compares dotted numeric versions (`1.10.0` > `1.9.2`); non-numeric parts
/// such as `-beta` are ignored. Returns <0, 0 or >0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.split('+').first.split('-').first.split('.'))
      int.tryParse(p) ?? 0,
  ];
  final x = parts(a);
  final y = parts(b);
  final length = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < length; i++) {
    final left = i < x.length ? x[i] : 0;
    final right = i < y.length ? y[i] : 0;
    if (left != right) return left.compareTo(right);
  }
  return 0;
}
