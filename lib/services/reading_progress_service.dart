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
  static String localDate([DateTime? time]) {
    final value = time ?? DateTime.now();
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static Future<void> addSeconds(String date, int seconds) async {
    if (seconds <= 0) return;
    final existing = SharedPreferencesService.getReadingSeconds(date);
    await SharedPreferencesService.setReadingSeconds(date, existing + seconds);
  }

  static ReadingProgress read() {
    final today = localDate();
    final target = SharedPreferencesService.getDailyTargetSeconds();
    final dates = SharedPreferencesService.getReadingDates();
    var total = 0;
    var longest = 0;
    var run = 0;
    for (final date in dates) {
      final seconds = SharedPreferencesService.getReadingSeconds(date);
      total += seconds;
      if (seconds >= target) {
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
    final todayDate = DateTime.parse(today);
    var cursor = SharedPreferencesService.getReadingSeconds(today) >= target
        ? todayDate
        : todayDate.subtract(const Duration(days: 1));
    var streak = 0;
    while (SharedPreferencesService.getReadingSeconds(localDate(cursor)) >=
        target) {
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

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _active = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!_active) return;
    final date = ReadingProgressService.localDate();
    _pending.update(date, (value) => value + 1, ifAbsent: () => 1);
    if (_pending[date]! % 15 == 0) unawaited(flush());
    onChanged();
  }

  Future<void> flush() async {
    final entries = Map<String, int>.from(_pending);
    _pending.clear();
    for (final entry in entries.entries) {
      await ReadingProgressService.addSeconds(entry.key, entry.value);
    }
    onChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) unawaited(flush());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await flush();
  }
}
