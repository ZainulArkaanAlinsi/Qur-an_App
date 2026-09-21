import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReadingProgress _compute(
  String today,
  Map<String, int> seconds, {
  int Function(String)? targetFor,
}) => StreakCalculator.compute(
  today: today,
  secondsByDate: seconds,
  targetFor: targetFor ?? (_) => 300,
);

void main() {
  group('StreakCalculator', () {
    test('299 detik belum memenuhi target, 300 detik memenuhi', () {
      expect(_compute('2026-05-04', {'2026-05-04': 299}).currentStreak, 0);
      final done = _compute('2026-05-04', {'2026-05-04': 300});
      expect(done.currentStreak, 1);
      expect(done.completedToday, isTrue);
      expect(done.remainingSeconds, 0);
    });

    test('contoh panduan: pending, putus, lalu mulai dari 1 lagi', () {
      final history = {
        '2026-05-04': 7 * 60, // Senin
        '2026-05-05': 11 * 60, // Selasa
        '2026-05-06': 3 * 60, // Rabu siang
      };
      final monday = _compute('2026-05-04', history);
      expect(monday.currentStreak, 1);

      final tuesday = _compute('2026-05-05', history);
      expect(tuesday.currentStreak, 2);

      final wednesday = _compute('2026-05-06', history);
      expect(wednesday.currentStreak, 2);
      expect(wednesday.pendingToday, isTrue);
      expect(wednesday.remainingSeconds, 120);

      final thursdayUnread = _compute('2026-05-07', history);
      expect(thursdayUnread.currentStreak, 0);
      expect(thursdayUnread.pendingToday, isFalse);
      expect(thursdayUnread.longestStreak, 2);

      final thursdayRead = _compute('2026-05-07', {
        ...history,
        '2026-05-07': 300,
      });
      expect(thursdayRead.currentStreak, 1);
      expect(thursdayRead.longestStreak, 2);
      expect(thursdayRead.totalSeconds, (7 + 11 + 3 + 5) * 60);
    });

    test('satu hari hanya menambah satu, berapapun menitnya', () {
      final progress = _compute('2026-05-04', {'2026-05-04': 3 * 3600});
      expect(progress.currentStreak, 1);
      expect(progress.longestStreak, 1);
    });

    test('melewati 29 Februari pada tahun kabisat', () {
      final progress = _compute('2028-03-01', {
        '2028-02-28': 300,
        '2028-02-29': 300,
        '2028-03-01': 300,
      });
      expect(progress.currentStreak, 3);
      expect(progress.longestStreak, 3);
    });

    test('melewati pergantian tahun', () {
      final progress = _compute('2027-01-01', {
        '2026-12-31': 300,
        '2027-01-01': 300,
      });
      expect(progress.currentStreak, 2);
    });

    test('target per tanggal memakai snapshot, bukan target terbaru', () {
      final targets = {'2026-05-04': 300, '2026-05-05': 600};
      final progress = _compute('2026-05-05', {
        '2026-05-04': 300,
        '2026-05-05': 400,
      }, targetFor: (d) => targets[d] ?? 600);
      expect(progress.currentStreak, 1);
      expect(progress.pendingToday, isTrue);
      expect(progress.targetSeconds, 600);
    });

    test('tanggal masa depan (jam dimundurkan) diabaikan', () {
      final progress = _compute('2026-05-04', {
        '2026-05-04': 300,
        '2026-05-10': 9000,
      });
      expect(progress.totalSeconds, 300);
      expect(progress.longestStreak, 1);
    });

    test('ringkasan tujuh hari terakhir urut dari yang terlama', () {
      final progress = _compute('2026-05-07', {
        '2026-05-01': 300,
        '2026-05-05': 300,
        '2026-05-07': 100,
      });
      expect(progress.recentDays, [
        true,
        false,
        false,
        false,
        true,
        false,
        false,
      ]);
    });
  });

  group('splitActiveSeconds', () {
    test('sesi dalam satu hari tidak dipecah', () {
      expect(
        splitActiveSeconds(
          previous: DateTime(2026, 5, 4, 10),
          now: DateTime(2026, 5, 4, 10, 1),
          activeSeconds: 60,
        ),
        {'2026-05-04': 60},
      );
    });

    test('sesi lintas tengah malam dipecah ke dua tanggal', () {
      expect(
        splitActiveSeconds(
          previous: DateTime(2026, 5, 4, 23, 59),
          now: DateTime(2026, 5, 5, 0, 1),
          activeSeconds: 120,
        ),
        {'2026-05-04': 60, '2026-05-05': 60},
      );
    });

    test('jam dimundurkan tidak menambah durasi', () {
      expect(
        splitActiveSeconds(
          previous: DateTime(2026, 5, 5, 0, 1),
          now: DateTime(2026, 5, 4, 23, 59),
          activeSeconds: 30,
        ),
        {'2026-05-04': 30},
      );
    });

    test('durasi nol tidak dicatat', () {
      expect(
        splitActiveSeconds(
          previous: DateTime(2026, 5, 4),
          now: DateTime(2026, 5, 4),
          activeSeconds: 0,
        ),
        isEmpty,
      );
    });
  });

  test('sesi boleh dicicil: 2 + 3 menit memenuhi target 5 menit', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    await ReadingProgressService.addSeconds('2026-05-04', 120);
    expect(
      ReadingProgressService.read(now: DateTime(2026, 5, 4, 9)).currentStreak,
      0,
    );
    await ReadingProgressService.addSeconds('2026-05-04', 180);
    final progress = ReadingProgressService.read(now: DateTime(2026, 5, 4, 21));
    expect(progress.todaySeconds, 300);
    expect(progress.currentStreak, 1);
  });

  test('membuka reader tanpa waktu aktif tidak menambah streak', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    await ReadingProgressService.addSeconds('2026-05-04', 0);
    await ReadingProgressService.addSeconds('2026-05-04', -5);
    final progress = ReadingProgressService.read(now: DateTime(2026, 5, 4));
    expect(progress.todaySeconds, 0);
    expect(progress.currentStreak, 0);
  });
}
