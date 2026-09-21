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
  });
  final int todaySeconds;
  final int targetSeconds;
  final int currentStreak;
  final int longestStreak;
  final int totalSeconds;
  bool get completedToday => todaySeconds >= targetSeconds;
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

  static ReadingProgress read({DateTime? now}) {
    final today = localDate(now);
    final target = SharedPreferencesService.getTargetForDate(today);
    final dates = SharedPreferencesService.getReadingDates();
    var total = 0;
    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final date in dates) {
      if (date.compareTo(today) > 0) continue;
      final currentDate = DateTime.tryParse('${date}T00:00:00Z');
      if (currentDate == null) continue;
      if (previous == null || currentDate.difference(previous).inDays != 1)
        run = 0;
      previous = currentDate;
      final seconds = SharedPreferencesService.getReadingSeconds(date);
      total += seconds;
      if (seconds >= SharedPreferencesService.getTargetForDate(date)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }
    final todaySeconds = SharedPreferencesService.getReadingSeconds(today);
    final current = _currentStreak(today, target);
    return ReadingProgress(
      todaySeconds: todaySeconds,
      targetSeconds: target,
      currentStreak: current,
      longestStreak: longest,
      totalSeconds: total,
    );
  }

  static int _currentStreak(String today, int target) {
    final todayDate = DateTime.parse('${today}T00:00:00Z');
    var cursor = SharedPreferencesService.getReadingSeconds(today) >= target
        ? todayDate
        : todayDate.subtract(const Duration(days: 1));
    var streak = 0;
    while (SharedPreferencesService.getReadingSeconds(localDate(cursor)) >=
        SharedPreferencesService.getTargetForDate(localDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
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
    final previous = _lastWallTime ?? now;
    final date = ReadingProgressService.localDate(now);
    final previousDate = ReadingProgressService.localDate(previous);
    // A monotonic duration prevents wall-clock changes from granting extra time.
    // When a tick crosses midnight, split only the measured active duration.
    var remaining = delta;
    if (date != previousDate && now.isAfter(previous)) {
      final midnight = DateTime(now.year, now.month, now.day);
      final afterMidnight = now.difference(midnight).inSeconds.clamp(0, delta);
      final beforeMidnight = delta - afterMidnight;
      if (beforeMidnight > 0) {
        _pending.update(
          previousDate,
          (v) => v + beforeMidnight,
          ifAbsent: () => beforeMidnight,
        );
      }
      remaining = afterMidnight;
    }
    _pending.update(date, (v) => v + remaining, ifAbsent: () => remaining);
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
