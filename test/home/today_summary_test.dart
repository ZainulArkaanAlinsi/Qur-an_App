import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/home/domain/today_summary.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';

/// docs/DATA.md §6: kartu "Hari ini".
ReadingProgress _progress({
  int today = 0,
  int target = 300,
  int streak = 0,
  List<bool> recent = const [],
}) => ReadingProgress(
  todaySeconds: today,
  targetSeconds: target,
  currentStreak: streak,
  longestStreak: streak,
  totalSeconds: today,
  recentDays: recent,
);

HomeSnapshot _snap({
  ReadingProgress? reading,
  DailySession? session,
  bool sessionAvailable = true,
  int memorized = 0,
  int doneToday = 0,
  int due = 0,
}) => HomeSnapshot(
  now: DateTime(2026, 10, 2, 9),
  reading: reading ?? _progress(),
  session: session,
  sessionAvailable: sessionAvailable,
  memorizedCount: memorized,
  murajaahDoneToday: doneToday,
  murajaahDue: [
    for (var i = 1; i <= due; i++)
      AyahMemorization(
        surah: 78,
        ayah: i,
        interval: 1,
        dueOn: DateTime(2026, 10, 2),
      ),
  ],
);

DailySession _session(SessionStep step, {bool completed = false}) =>
    DailySession(date: '2026-10-02', step: step, completed: completed);

void main() {
  test('hari pertama: semua nol → kalimat ajakan, bukan angka menghakimi', () {
    final summary = summarizeToday(_snap(memorized: 1, due: 1));
    expect(
      summary.hint,
      'Hari pertama. Lima menit membaca sudah cukup untuk mulai.',
    );
  });

  test('semua cincin penuh → "Semua target hari ini tercapai."', () {
    final summary = summarizeToday(
      _snap(
        reading: _progress(today: 420, target: 300, streak: 5),
        session: _session(SessionStep.done, completed: true),
        memorized: 10,
        doneToday: 10,
      ),
    );
    expect(summary.rings.every((ring) => ring.full), isTrue);
    expect(summary.hint, 'Semua target hari ini tercapai. Alhamdulillah.');
  });

  test('sebagian → tanpa kalimat bantu', () {
    final summary = summarizeToday(
      _snap(
        reading: _progress(today: 180, target: 300, streak: 4),
        session: _session(SessionStep.findInVerse),
        memorized: 10,
        due: 10,
      ),
    );
    expect(summary.hint, isNull);
    final sesi = summary.rings.firstWhere((r) => r.kind == TodayRingKind.sesi);
    expect(sesi.value, 2);
    expect(sesi.fill, closeTo(2 / 5, 1e-9));
    expect(summary.rings.first.value, 3);
    expect(summary.rings.first.total, 5);
  });

  test('cincin Sesi disembunyikan bila tidak ada materi terbit', () {
    final summary = summarizeToday(_snap(sessionAvailable: false));
    expect(
      summary.rings.map((r) => r.kind),
      isNot(contains(TodayRingKind.sesi)),
    );
  });

  test('cincin Murajaah disembunyikan bila belum pernah menghafal', () {
    final summary = summarizeToday(_snap());
    expect(
      summary.rings.map((r) => r.kind),
      isNot(contains(TodayRingKind.murajaah)),
    );
  });

  test('murajaah tanpa jadwal: kosong + "Tidak ada jadwal", bukan penuh', () {
    final summary = summarizeToday(
      _snap(memorized: 5, reading: _progress(today: 60, streak: 1)),
    );
    final ring = summary.rings.firstWhere(
      (r) => r.kind == TodayRingKind.murajaah,
    );
    expect(ring.fill, 0);
    expect(ring.full, isFalse);
    expect(ring.note, 'Tidak ada jadwal');
  });

  test('target 0 detik tidak membagi nol', () {
    final empty = summarizeToday(_snap(reading: _progress(target: 0)));
    expect(empty.rings.first.fill, 0);
    final read = summarizeToday(
      _snap(reading: _progress(today: 60, target: 0, streak: 1)),
    );
    expect(read.rings.first.fill, 1);
    for (final ring in [...empty.rings, ...read.rings]) {
      expect(ring.fill.isFinite, isTrue);
    }
  });

  test('pekan selalu 7 hari, hari ini di akhir', () {
    final summary = summarizeToday(
      _snap(reading: _progress(recent: [true, false, true], streak: 1)),
    );
    expect(summary.week, [false, false, false, false, true, false, true]);
  });
}
