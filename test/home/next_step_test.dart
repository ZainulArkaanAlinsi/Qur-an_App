import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/home/domain/next_step.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';

/// docs/DATA.md §6: tabel kasus NextStepEngine.
final _now = DateTime(2026, 10, 2, 9);

ReadingProgress _progress({int today = 0, int target = 300}) => ReadingProgress(
  todaySeconds: today,
  targetSeconds: target,
  currentStreak: 0,
  longestStreak: 0,
  totalSeconds: today,
);

AyahMemorization _due(int surah, int ayah, {int daysLate = 0}) =>
    AyahMemorization(
      surah: surah,
      ayah: ayah,
      interval: 1,
      dueOn: DateTime(2026, 10, 2 - daysLate),
    );

DailySession _session(
  SessionStep step, {
  bool completed = false,
  Set<SessionStep> skipped = const {},
}) => DailySession(
  date: '2026-10-02',
  step: step,
  completed: completed,
  skipped: skipped,
);

HomeSnapshot _snap({
  LastRead? lastRead,
  ReadingProgress? reading,
  DailySession? session,
  bool sessionAvailable = true,
  List<AyahMemorization> due = const [],
  StartPoint startPoint = StartPoint.tajwid,
  Lesson? nextLesson,
  NowPlaying? nowPlaying,
}) => HomeSnapshot(
  now: _now,
  lastRead: lastRead,
  reading: reading ?? _progress(),
  session: session,
  sessionAvailable: sessionAvailable,
  memorizedCount: due.length,
  murajaahDue: due,
  startPoint: startPoint,
  nextLesson: nextLesson,
  nowPlaying: nowPlaying,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pengguna baru (tanpa bacaan, sesi tersedia) → sesi hari ini', () {
    final result = decideNextStep(_snap());
    expect(result.primary.kind, NextStepKind.startSession);
    expect(result.primary.title, 'Sesi hari ini');
    expect(result.primary.cta, 'Mulai sesi');
    expect(result.primary.badge, '±10 mnt');
    expect(result.alternatives.first.eyebrow, 'BACA');
    expect(result.alternatives.first.text, 'Al-Fatihah · ayat 1');
  });

  test('sesi di langkah 3 → lanjutkan sesi walau murajaah jatuh tempo', () {
    final result = decideNextStep(
      _snap(
        session: _session(SessionStep.findInVerse),
        due: [_due(78, 1)],
        startPoint: StartPoint.hafalan,
      ),
    );
    expect(result.primary.kind, NextStepKind.resumeSession);
    expect(result.primary.subtitle, 'Langkah 3 dari 5 · Temukan di ayat');
    expect(result.primary.badge, '±6 mnt');
    expect(result.primary.sessionStep, 2);
    expect(result.primary.cta, 'Lanjutkan');
  });

  test('langkah dilewati juga dihitung sesi berjalan', () {
    final result = decideNextStep(
      _snap(
        session: _session(SessionStep.warmup, skipped: {SessionStep.warmup}),
      ),
    );
    expect(result.primary.kind, NextStepKind.resumeSession);
  });

  test('titik mulai hafalan + murajaah → murajaah', () {
    final result = decideNextStep(
      _snap(
        startPoint: StartPoint.hafalan,
        due: [for (var a = 1; a <= 10; a++) _due(78, a)],
      ),
    );
    expect(result.primary.kind, NextStepKind.murajaah);
    expect(result.primary.title, 'Murajaah An-Naba’ 1⁠–⁠10');
    expect(result.primary.badge, '10 ayat');
    expect(result.primary.cta, 'Mulai murajaah');
    // Keputusan 2026-10-02: murajaah membuka tab Hafalan.
    expect(result.primary.action, NextStepAction.openHafalan);
  });

  test('titik mulai lain: sesi didahulukan dari murajaah', () {
    final result = decideNextStep(_snap(due: [_due(78, 1)]));
    expect(result.primary.kind, NextStepKind.startSession);
    expect(result.alternatives.map((a) => a.eyebrow), contains('MURAJAAH'));
  });

  test('sesi selesai + murajaah 0 → bacaan dengan "Sesi selesai ✓"', () {
    final result = decideNextStep(
      _snap(
        session: _session(SessionStep.done, completed: true),
        lastRead: const LastRead(surah: 18, ayah: 23, page: 296),
        reading: _progress(today: 120, target: 300),
      ),
    );
    expect(result.primary.kind, NextStepKind.reading);
    expect(result.primary.title, 'Al-Kahf · ayat 23');
    expect(
      result.primary.subtitle,
      'Sesi selesai ✓ · 3 mnt lagi ke target hari ini',
    );
    expect(result.primary.badge, 'Hal. 296');
    expect(result.primary.cta, 'Lanjut membaca');
  });

  test('tidak ada materi terbit → tidak pernah sesi', () {
    for (final due in [
      <AyahMemorization>[],
      [_due(78, 1)],
    ]) {
      final result = decideNextStep(_snap(sessionAvailable: false, due: due));
      expect(result.primary.kind, isNot(NextStepKind.startSession));
      expect(
        result.alternatives.map((a) => a.eyebrow),
        isNot(contains('SESI HARI INI')),
      );
    }
  });

  test('murajaah terlewat 2 hari → subjudul memuat "2 hari terlewat"', () {
    final result = decideNextStep(
      _snap(
        sessionAvailable: false,
        due: [_due(78, 1, daysLate: 2), _due(78, 2)],
      ),
    );
    expect(result.primary.kind, NextStepKind.murajaah);
    expect(result.primary.subtitle, '2 ayat jatuh tempo · 2 hari terlewat');
  });

  test('tanpa bacaan terakhir → "Mulai membaca" / "Buka Al-Fatihah"', () {
    final result = decideNextStep(_snap(sessionAvailable: false));
    expect(result.primary.title, 'Mulai membaca');
    expect(result.primary.cta, 'Buka Al-Fatihah');
    expect(result.primary.badge, isNull);
  });

  test('target tercapai → "Target hari ini tercapai"', () {
    final result = decideNextStep(
      _snap(
        sessionAvailable: false,
        reading: _progress(today: 400, target: 300),
      ),
    );
    expect(result.primary.subtitle, 'Target hari ini tercapai');
  });

  test('surah bacaan terakhir sedang diputar → pilihan DIPUTAR', () {
    final result = decideNextStep(
      _snap(
        lastRead: const LastRead(surah: 1, ayah: 3),
        nowPlaying: const NowPlaying(surah: 1, ayah: 3),
      ),
    );
    final read = result.alternatives.first;
    expect(read.eyebrow, 'DIPUTAR');
    expect(read.action, NextStepAction.openPlayer);
  });

  test('surah bacaan diputar → DIPUTAR saja, tanpa DENGAR yang sama', () {
    final result = decideNextStep(
      _snap(
        lastRead: const LastRead(surah: 1, ayah: 3),
        nowPlaying: const NowPlaying(surah: 1, ayah: 3),
      ),
    );
    expect(result.alternatives.map((a) => a.eyebrow), ['DIPUTAR']);
  });

  test('murottal lain diputar → pilihan DENGAR mengisi slot kosong', () {
    final result = decideNextStep(
      _snap(
        lastRead: const LastRead(surah: 1, ayah: 3),
        nowPlaying: const NowPlaying(surah: 18, ayah: 23),
      ),
    );
    expect(result.alternatives.map((a) => a.eyebrow), ['BACA', 'DENGAR']);
    expect(result.alternatives.last.text, 'Murottal Al-Kahf ayat 23');
  });

  test(
    'sesi selesai + pelajaran berikutnya → SESI BESOK ke tab Belajar',
    () async {
      final curriculum = await CurriculumRepository.load();
      final lesson = curriculum.nextAfter({}, includeDrafts: true)!;
      final result = decideNextStep(
        _snap(
          session: _session(SessionStep.done, completed: true),
          lastRead: const LastRead(surah: 18, ayah: 23),
          nextLesson: lesson,
        ),
      );
      final tomorrow = result.alternatives.last;
      expect(tomorrow.eyebrow, 'SESI BESOK');
      expect(tomorrow.text, lesson.title);
      expect(tomorrow.action, NextStepAction.openLearn);
    },
  );

  test('pilihan lain tidak pernah > 2 dan tidak mengulang kartu utama', () {
    final sessions = <DailySession?>[
      null,
      _session(SessionStep.newMaterial),
      _session(SessionStep.done, completed: true),
    ];
    for (final session in sessions) {
      for (final available in [true, false]) {
        for (final due in [
          <AyahMemorization>[],
          [_due(78, 1)],
        ]) {
          for (final start in StartPoint.values) {
            for (final playing in [null, const NowPlaying(surah: 2, ayah: 5)]) {
              final result = decideNextStep(
                _snap(
                  session: session,
                  sessionAvailable: available,
                  due: due,
                  startPoint: start,
                  nowPlaying: playing,
                ),
              );
              expect(result.alternatives.length, lessThanOrEqualTo(2));
              final primaryEyebrow = switch (result.primary.kind) {
                NextStepKind.reading => 'BACA',
                NextStepKind.murajaah => 'MURAJAAH',
                NextStepKind.startSession ||
                NextStepKind.resumeSession => 'SESI HARI INI',
              };
              expect(
                result.alternatives.map((a) => a.eyebrow),
                isNot(contains(primaryEyebrow)),
              );
            }
          }
        }
      }
    }
  });

  test('deterministik: snapshot sama → hasil sama', () {
    final snapshot = _snap(
      lastRead: const LastRead(surah: 67, ayah: 12),
      due: [_due(78, 1, daysLate: 1)],
      session: _session(SessionStep.warmup),
    );
    final a = decideNextStep(snapshot);
    final b = decideNextStep(snapshot);
    expect(a.primary.kind, b.primary.kind);
    expect(a.primary.title, b.primary.title);
    expect(a.primary.subtitle, b.primary.subtitle);
    expect(
      a.alternatives.map((x) => '${x.eyebrow}|${x.text}').toList(),
      b.alternatives.map((x) => '${x.eyebrow}|${x.text}').toList(),
    );
  });
}
