import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One contiguous stretch of active reading on a single local date.
///
/// A reader visit that crosses midnight, or is paused and resumed, produces
/// several sessions. Sessions are keyed by [id], so saving the same session
/// again replaces it instead of adding its seconds twice.
@immutable
class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.deviceId,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.activeSeconds,
    required this.timezone,
    required this.localDate,
    this.mode = 'reading',
    this.lastVerseKey,
    this.syncStatus = 'local',
  });

  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
    id: json['id'] as String,
    deviceId: json['deviceId'] as String,
    startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
    endedAtUtc: json['endedAtUtc'] == null
        ? null
        : DateTime.parse(json['endedAtUtc'] as String),
    activeSeconds: json['activeSeconds'] as int,
    timezone: json['timezone'] as String,
    localDate: json['localDate'] as String,
    mode: json['mode'] as String? ?? 'reading',
    lastVerseKey: json['lastVerseKey'] as String?,
    syncStatus: json['syncStatus'] as String? ?? 'local',
  );

  final String id;

  /// Random per-install identifier; carries no personal data.
  final String deviceId;
  final DateTime startedAtUtc;

  /// Null while the session is still open.
  final DateTime? endedAtUtc;

  /// Monotonic active time, never derived from wall-clock differences.
  final int activeSeconds;

  /// IANA zone at the time of reading, e.g. `Asia/Jakarta`.
  final String timezone;
  final String localDate;
  final String mode;
  final String? lastVerseKey;

  /// `local` until a future sync layer confirms the upload.
  final String syncStatus;

  ReadingSession copyWith({
    DateTime? endedAtUtc,
    int? activeSeconds,
    String? lastVerseKey,
    String? syncStatus,
  }) => ReadingSession(
    id: id,
    deviceId: deviceId,
    startedAtUtc: startedAtUtc,
    endedAtUtc: endedAtUtc ?? this.endedAtUtc,
    activeSeconds: activeSeconds ?? this.activeSeconds,
    timezone: timezone,
    localDate: localDate,
    mode: mode,
    lastVerseKey: lastVerseKey ?? this.lastVerseKey,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    'endedAtUtc': endedAtUtc?.toUtc().toIso8601String(),
    'activeSeconds': activeSeconds,
    'timezone': timezone,
    'localDate': localDate,
    'mode': mode,
    'lastVerseKey': lastVerseKey,
    'syncStatus': syncStatus,
  };
}

/// Persists reading sessions and derives each day's total from them.
///
/// Daily totals in `reading_seconds_<date>` are a cache recomputed as
/// legacy seconds (recorded before sessions existed) plus the sum of that
/// date's sessions, so re-saving a session is idempotent.
class ReadingSessionStore {
  ReadingSessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _sessionPrefix = 'reading_session_';
  static const _legacyPrefix = 'reading_legacy_seconds_';
  static const _dailyPrefix = 'reading_seconds_';
  static const _deviceKey = 'reading_device_id';
  static const _migratedKey = 'reading_sessions_migrated_v1';

  /// Moves pre-session daily totals into legacy keys once, so existing
  /// streak history survives the switch to session-derived totals.
  Future<void> migrateLegacyTotals() async {
    if (_prefs.getBool(_migratedKey) == true) return;
    for (final key in _prefs.getKeys().toList()) {
      if (!key.startsWith(_dailyPrefix)) continue;
      final date = key.substring(_dailyPrefix.length);
      final seconds = _prefs.getInt(key) ?? 0;
      if (seconds > 0) await _prefs.setInt('$_legacyPrefix$date', seconds);
    }
    await _prefs.setBool(_migratedKey, true);
  }

  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceKey);
    if (existing != null) return existing;
    final created = newUuid();
    await _prefs.setString(_deviceKey, created);
    return created;
  }

  /// Inserts or replaces [session] and refreshes its date's total.
  Future<void> save(ReadingSession session) async {
    if (session.activeSeconds <= 0) return;
    await migrateLegacyTotals();
    // The date in the key lets one day's sessions be read without
    // decoding the whole history.
    await _prefs.setString(
      '$_sessionPrefix${session.localDate}_${session.id}',
      jsonEncode(session.toJson()),
    );
    await recompute(session.localDate);
  }

  List<ReadingSession> all() => _read(_sessionPrefix);

  /// Closed sessions not yet confirmed by the server (the outbox).
  List<ReadingSession> pendingUpload() => [
    for (final s in all())
      if (s.syncStatus == 'local' && s.endedAtUtc != null) s,
  ];

  /// Stores many sessions, recomputing each affected date once.
  Future<void> saveAll(Iterable<ReadingSession> sessions) async {
    await migrateLegacyTotals();
    final dates = <String>{};
    for (final session in sessions) {
      if (session.activeSeconds <= 0) continue;
      await _prefs.setString(
        '$_sessionPrefix${session.localDate}_${session.id}',
        jsonEncode(session.toJson()),
      );
      dates.add(session.localDate);
    }
    for (final date in dates) {
      await recompute(date);
    }
  }

  /// Removes sessions that came from or went to a cloud account, keeping
  /// local-only history; used when a different account signs in.
  Future<void> removeSynced() async {
    final dates = <String>{};
    for (final key in _prefs.getKeys().toList()) {
      if (!key.startsWith(_sessionPrefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final session = ReadingSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (session.syncStatus != 'synced') continue;
        await _prefs.remove(key);
        dates.add(session.localDate);
      } on Object {
        continue;
      }
    }
    for (final date in dates) {
      await recompute(date);
    }
  }

  List<ReadingSession> forDate(String date) => _read('$_sessionPrefix${date}_');

  List<ReadingSession> _read(String prefix) {
    final sessions = <ReadingSession>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        sessions.add(
          ReadingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } on Object catch (error) {
        // A corrupt record must not block reading; it is skipped, not lost.
        debugPrint('Sesi baca rusak diabaikan ($key): $error');
      }
    }
    return sessions..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  }

  int legacySeconds(String date) => _prefs.getInt('$_legacyPrefix$date') ?? 0;

  /// Rebuilds the cached total for [date] from legacy seconds and sessions.
  Future<int> recompute(String date) async {
    // Never overwrite a pre-session total before it is preserved.
    await migrateLegacyTotals();
    final total = legacySeconds(date) + mergedActiveSeconds(forDate(date));
    await _prefs.setInt('$_dailyPrefix$date', total);
    return total;
  }
}

/// Sums active seconds, counting time read on several devices at once only
/// once, so reading on two or more phones simultaneously is not multiplied.
///
/// Duplicate time is `sum of each device's own covered time - covered time
/// of all devices together`, which stays correct for any number of
/// overlapping devices. Sessions from one device are always summed in full,
/// and the result never drops below the busiest single device's total.
int mergedActiveSeconds(List<ReadingSession> sessions) {
  final byDevice = <String, List<ReadingSession>>{};
  for (final s in sessions) {
    (byDevice[s.deviceId] ??= []).add(s);
  }
  final active = sessions.fold<int>(0, (sum, s) => sum + s.activeSeconds);
  if (byDevice.length < 2) return active;
  final perDeviceCovered = byDevice.values.fold<int>(
    0,
    (sum, list) => sum + _coveredSeconds(list),
  );
  final duplicated = perDeviceCovered - _coveredSeconds(sessions);
  final floor = byDevice.values
      .map((list) => list.fold<int>(0, (sum, s) => sum + s.activeSeconds))
      .reduce(max);
  return max(active - duplicated, floor);
}

/// Length of the union of the sessions' wall-clock windows, in seconds.
int _coveredSeconds(List<ReadingSession> sessions) {
  final windows = [
    for (final s in sessions)
      (
        s.startedAtUtc,
        s.endedAtUtc ?? s.startedAtUtc.add(Duration(seconds: s.activeSeconds)),
      ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var total = 0;
  DateTime? start;
  DateTime? end;
  for (final (from, to) in windows) {
    if (end == null || from.isAfter(end)) {
      if (start != null) total += end!.difference(start).inSeconds;
      start = from;
      end = to;
    } else if (to.isAfter(end)) {
      end = to;
    }
  }
  if (start != null) total += end!.difference(start).inSeconds;
  return total;
}

final _random = Random.secure();

/// RFC 4122 version 4 UUID from a cryptographically secure source.
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
