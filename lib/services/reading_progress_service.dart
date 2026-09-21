import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

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

  static Future<void> addSeconds(String date, int seconds) {
    final write = _writes.then((_) async {
      if (seconds <= 0) return;
      await SharedPreferencesService.ensureTargetSnapshot(date);
      final existing = SharedPreferencesService.getReadingSeconds(date);
      await SharedPreferencesService.setReadingSeconds(
        date,
        existing + seconds,
      );
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

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
      unawaited(flush());
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
      unawaited(flush());
    }
    if (!_disposed) onChanged();
  }

  Future<void> flush() async {
    final entries = Map<String, int>.from(_pending);
    _pending.clear();
    for (final entry in entries.entries) {
      await ReadingProgressService.addSeconds(entry.key, entry.value);
    }
    if (!_disposed) onChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tick();
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _clock.stop();
      unawaited(flush());
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
    await flush();
  }
}
