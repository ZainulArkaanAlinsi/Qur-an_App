import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quran_app_2025/services/reading_session_store.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.todaySeconds,
    required this.targetSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalSeconds,
    this.pendingToday = false,
    this.recentDays = const [],
  });
  final int todaySeconds;
  final int targetSeconds;
  final int currentStreak;
  final int longestStreak;
  final int totalSeconds;

  /// True when yesterday qualified but today has not reached the target yet,
  /// so [currentStreak] is still carried and will break after midnight.
  final bool pendingToday;

  /// Oldest-first qualifying flags for the last seven local dates.
  final List<bool> recentDays;
  bool get completedToday => todaySeconds >= targetSeconds;
  int get remainingSeconds => completedToday ? 0 : targetSeconds - todaySeconds;
}

/// Pure streak rules from the guide (section 6): one increment per qualifying
/// day, today pending while yesterday qualified, reset after a missed day.
class StreakCalculator {
  static ReadingProgress compute({
    required String today,
    required Map<String, int> secondsByDate,
    required int Function(String date) targetFor,
  }) {
    bool qualifies(String date) =>
        (secondsByDate[date] ?? 0) >= targetFor(date);

    final dates =
        secondsByDate.keys.where((d) => d.compareTo(today) <= 0).toList()
          ..sort();
    var total = 0;
    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final date in dates) {
      final day = _parse(date);
      if (day == null) continue;
      total += secondsByDate[date] ?? 0;
      if (previous == null || day.difference(previous).inDays != 1) {
        run = 0;
      }
      previous = day;
      run = qualifies(date) ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    final todayDate = _parse(today)!;
    final todayQualifies = qualifies(today);
    var cursor = todayQualifies
        ? todayDate
        : todayDate.subtract(const Duration(days: 1));
    var current = 0;
    while (qualifies(_format(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return ReadingProgress(
      todaySeconds: secondsByDate[today] ?? 0,
      targetSeconds: targetFor(today),
      currentStreak: current,
      longestStreak: longest,
      totalSeconds: total,
      pendingToday: !todayQualifies && current > 0,
      recentDays: [
        for (var offset = 6; offset >= 0; offset--)
          qualifies(_format(todayDate.subtract(Duration(days: offset)))),
      ],
    );
  }

  // Calendar arithmetic runs in UTC so DST shifts never skip or repeat a date.
  static DateTime? _parse(String date) =>
      DateTime.tryParse('${date}T00:00:00Z');
  static String _format(DateTime date) =>
      ReadingProgressService.localDate(date);
}

/// Splits [activeSeconds] measured between [previous] and [now] into local
/// dates, so a session crossing midnight credits both days separately.
Map<String, int> splitActiveSeconds({
  required DateTime previous,
  required DateTime now,
  required int activeSeconds,
}) {
  if (activeSeconds <= 0) return const {};
  final date = ReadingProgressService.localDate(now);
  final previousDate = ReadingProgressService.localDate(previous);
  if (date == previousDate || !now.isAfter(previous)) {
    return {date: activeSeconds};
  }
  final midnight = DateTime(now.year, now.month, now.day);
  final after = now.difference(midnight).inSeconds.clamp(0, activeSeconds);
  final before = activeSeconds - after;
  return {if (before > 0) previousDate: before, if (after > 0) date: after};
}

class ReadingProgressService {
  static Future<void> _writes = Future<void>.value();
  static String localDate([DateTime? time]) {
    final value = time ?? DateTime.now();
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  // SharedPreferences caches its own instance; a fresh store per call keeps
  // tests that reset mock preferences isolated.
  static Future<ReadingSessionStore> store() async =>
      ReadingSessionStore(await SharedPreferences.getInstance());

  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Future<String> _timezone() async {
    try {
      return await FlutterTimezone.getLocalTimezone();
    } on Object {
      // Fallback keeps reading tracked where the plugin is unavailable.
      return DateTime.now().timeZoneName;
    }
  }

  /// Creates an empty, open session for [date]; nothing is stored until it
  /// has active seconds.
  static Future<ReadingSession> openSession(
    String date, {
    String? verseKey,
    DateTime? startedAtUtc,
  }) async => ReadingSession(
    id: newUuid(),
    deviceId: await (await store()).deviceId(),
    startedAtUtc: (startedAtUtc ?? DateTime.now()).toUtc(),
    endedAtUtc: null,
    activeSeconds: 0,
    timezone: await _timezone(),
    localDate: date,
    lastVerseKey: verseKey,
  );

  /// Stores [session] (replacing any earlier copy) and recomputes its day.
  static Future<void> saveSession(ReadingSession session) =>
      _serial(() => _save(session));

  static Future<void> _save(ReadingSession session) async {
    if (session.activeSeconds <= 0) return;
    await SharedPreferencesService.ensureTargetSnapshot(session.localDate);
    await (await store()).save(session);
  }

  /// Records [seconds] of reading on [date] as one closed session.
  static Future<void> addSeconds(String date, int seconds) => _serial(() async {
    if (seconds <= 0) return;
    final now = DateTime.now().toUtc();
    // Backdate the start so the session spans its own active time.
    final session = await openSession(
      date,
      startedAtUtc: now.subtract(Duration(seconds: seconds)),
    );
    await _save(session.copyWith(activeSeconds: seconds, endedAtUtc: now));
  });

  static ReadingProgress read({DateTime? now}) => StreakCalculator.compute(
    today: localDate(now),
    secondsByDate: {
      for (final date in SharedPreferencesService.getReadingDates())
        date: SharedPreferencesService.getReadingSeconds(date),
    },
    targetFor: SharedPreferencesService.getTargetForDate,
  );
}

class ReadingSessionTracker with WidgetsBindingObserver {
  ReadingSessionTracker({required this.onChanged});
  final VoidCallback onChanged;
  Timer? _timer;
  final Map<String, int> _pending = {};
  bool _active = false;
  bool _started = false;
  bool _disposed = false;
  bool _paused = false;
  bool needsConfirmation = false;

  /// Verse the reader is on, stored with the session as `lastVerseKey`.
  String? verseKey;
  ReadingSession? _session;
  Future<void> _flushing = Future<void>.value();
  final Stopwatch _clock = Stopwatch();
  int _accounted = 0;
  int _lastInteraction = 0;
  DateTime? _lastWallTime;

  bool get paused => _paused || needsConfirmation;

  void interact() {
    _lastInteraction = _clock.elapsed.inSeconds;
  }

  void setPaused(bool value) {
    _tick();
    _paused = value;
    needsConfirmation = false;
    interact();
    if (value) {
      _clock.stop();
      unawaited(flush(endSession: true));
    } else if (_active) {
      _lastWallTime = DateTime.now();
      _clock.start();
    }
    if (!_disposed) onChanged();
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _lastWallTime = DateTime.now();
    if (_active) _clock.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!_active || paused || _disposed) return;
    final elapsed = _clock.elapsed.inSeconds;
    final delta = elapsed - _accounted;
    if (delta <= 0) return;
    final now = DateTime.now();
    // A monotonic duration prevents wall-clock changes from granting extra time.
    // When a tick crosses midnight, split only the measured active duration.
    splitActiveSeconds(
      previous: _lastWallTime ?? now,
      now: now,
      activeSeconds: delta,
    ).forEach(
      (date, seconds) =>
          _pending.update(date, (v) => v + seconds, ifAbsent: () => seconds),
    );
    _accounted = elapsed;
    _lastWallTime = now;
    if (elapsed - _lastInteraction >= 300) {
      needsConfirmation = true;
      _clock.stop();
    }
    if (_pending.values.fold<int>(0, (a, b) => a + b) >= 5 ||
        needsConfirmation) {
      unawaited(flush(endSession: needsConfirmation));
    }
    if (!_disposed) onChanged();
  }

  /// Writes pending seconds into the open session, opening a new one per
  /// local date. [endSession] closes it (pause, background, idle, exit).
  /// Calls are queued so concurrent flushes never open two sessions.
  Future<void> flush({bool endSession = false}) {
    final result = _flushing.then((_) => _flush(endSession));
    _flushing = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _flush(bool endSession) async {
    final entries = Map<String, int>.from(_pending);
    _pending.clear();
    for (final entry in entries.entries) {
      var session = _session;
      if (session != null && session.localDate != entry.key) {
        // Crossing midnight: the previous date's session ends here.
        await ReadingProgressService.saveSession(
          session.copyWith(endedAtUtc: DateTime.now().toUtc()),
        );
        session = null;
      }
      // The first flush happens a few seconds in, so backdate the start by
      // the seconds already measured.
      session ??= await ReadingProgressService.openSession(
        entry.key,
        verseKey: verseKey,
        startedAtUtc: DateTime.now().subtract(Duration(seconds: entry.value)),
      );
      session = session.copyWith(
        activeSeconds: session.activeSeconds + entry.value,
        lastVerseKey: verseKey,
      );
      _session = session;
      await ReadingProgressService.saveSession(session);
    }
    final open = _session;
    if (endSession && open != null) {
      _session = null;
      await ReadingProgressService.saveSession(
        open.copyWith(
          endedAtUtc: DateTime.now().toUtc(),
          lastVerseKey: verseKey,
        ),
      );
    }
    if (!_disposed) onChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tick();
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _clock.stop();
      unawaited(flush(endSession: true));
    } else if (!paused) {
      _lastWallTime = DateTime.now();
      _clock.start();
    }
  }

  Future<void> dispose() async {
    _tick();
    _disposed = true;
    _clock.stop();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await flush(endSession: true);
  }
}
