import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';

/// Jenis "Langkah berikutnya" (docs/DATA.md §2).
enum NextStepKind { resumeSession, startSession, murajaah, reading }

/// Ke mana kartu atau pilihan lain membawa pengguna (DATA §2.4).
enum NextStepAction {
  /// `SessionScreen(now:)`.
  openSession,

  /// Tab Hafalan (keputusan 2026-10-02: tanpa layar antrean baru).
  openHafalan,

  /// `ReaderScreen` di bacaan terakhir; Al-Fatihah 1 bila belum pernah.
  openReader,

  /// Layar Murottal.
  openPlayer,

  /// Tab Belajar ("Sesi besok": tidak memulai sesi baru).
  openLearn,
}

/// Kartu hijau "Langkah berikutnya".
@immutable
class NextStep {
  const NextStep({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.action,
    this.badge,
    this.sessionStep,
  });

  final NextStepKind kind;
  final String title;
  final String subtitle;
  final String cta;
  final NextStepAction action;

  /// Pill kanan atas: "±10 mnt", "10 ayat", "Hal. 296".
  final String? badge;

  /// 0..4, hanya untuk sesi (langkah sekarang di Lintasan).
  final int? sessionStep;
}

/// Satu baris "pilihan lain" di dalam kartu.
@immutable
class NextStepAlt {
  const NextStepAlt({
    required this.eyebrow,
    required this.text,
    required this.action,
  });

  /// BACA / DIPUTAR / MURAJAAH / SESI HARI INI / DENGAR / SESI BESOK.
  final String eyebrow;
  final String text;
  final NextStepAction action;
}

@immutable
class NextStepResult {
  const NextStepResult({required this.primary, required this.alternatives});

  final NextStep primary;

  /// Maksimal 2, tidak pernah mengulang [primary].
  final List<NextStepAlt> alternatives;
}

/// Jumlah langkah sesi harian (v5).
const sessionStepCount = 5;

/// Memilih satu langkah utama + paling banyak dua pilihan lain.
///
/// Urutan (DATA §2.2, berhenti di aturan pertama yang cocok):
/// 1. sesi setengah jalan → lanjutkan sesi;
/// 2. titik mulai hafalan + ada murajaah → murajaah;
/// 3. sesi bisa dimulai → sesi hari ini;
/// 4. ada murajaah → murajaah;
/// 5. bacaan.
///
/// Tidak ada aturan jam atau acak: snapshot yang sama selalu memberi hasil
/// yang sama.
NextStepResult decideNextStep(HomeSnapshot s) {
  final candidates = <NextStepKind, NextStep>{};
  final session = s.session;
  final started =
      session != null &&
      !session.completed &&
      (session.step.index > 0 || session.skipped.isNotEmpty);
  if (started) {
    candidates[NextStepKind.resumeSession] = _resume(session);
  }
  if (s.sessionAvailable &&
      (session == null || (!session.completed && !started))) {
    candidates[NextStepKind.startSession] = _start(s);
  }
  if (s.murajaahDue.isNotEmpty) {
    candidates[NextStepKind.murajaah] = _murajaah(s);
  }
  candidates[NextStepKind.reading] = _reading(s);

  final NextStepKind primary;
  if (candidates.containsKey(NextStepKind.resumeSession)) {
    primary = NextStepKind.resumeSession;
  } else if (s.startPoint == StartPoint.hafalan &&
      candidates.containsKey(NextStepKind.murajaah)) {
    primary = NextStepKind.murajaah;
  } else if (candidates.containsKey(NextStepKind.startSession)) {
    primary = NextStepKind.startSession;
  } else if (candidates.containsKey(NextStepKind.murajaah)) {
    primary = NextStepKind.murajaah;
  } else {
    primary = NextStepKind.reading;
  }

  // Pilihan lain (DATA §2.3): urutan tetap bacaan, murajaah, sesi.
  final alternatives = <NextStepAlt>[];
  for (final kind in const [
    NextStepKind.reading,
    NextStepKind.murajaah,
    NextStepKind.startSession,
    NextStepKind.resumeSession,
  ]) {
    if (kind == primary || !candidates.containsKey(kind)) continue;
    alternatives.add(_alt(kind, s));
  }
  final playing = s.nowPlaying;
  // Baris bacaan yang sudah menjadi DIPUTAR (surah yang sama) sudah membuka
  // pemutar; DENGAR untuk murottal yang sama hanya mengulang informasi.
  final readingIsPlaying = alternatives.any((a) => a.eyebrow == 'DIPUTAR');
  if (playing != null && primary != NextStepKind.reading && !readingIsPlaying) {
    final name = surahCatalog[playing.surah - 1].displayName;
    alternatives.add(
      NextStepAlt(
        eyebrow: 'DENGAR',
        text: 'Murottal $name ayat ${playing.ayah}',
        action: NextStepAction.openPlayer,
      ),
    );
  }
  final lesson = s.nextLesson;
  if (s.sessionCompleted && lesson != null) {
    alternatives.add(
      NextStepAlt(
        eyebrow: 'SESI BESOK',
        text: lesson.title,
        action: NextStepAction.openLearn,
      ),
    );
  }
  return NextStepResult(
    primary: candidates[primary]!,
    alternatives: alternatives.take(2).toList(growable: false),
  );
}

NextStep _resume(DailySession session) {
  final step = session.step;
  final remaining = sessionStepCount - step.index;
  return NextStep(
    kind: NextStepKind.resumeSession,
    title: 'Lanjutkan sesi',
    subtitle:
        'Langkah ${step.index + 1} dari $sessionStepCount · ${step.title}',
    cta: 'Lanjutkan',
    action: NextStepAction.openSession,
    badge: '±${remaining * 2} mnt',
    sessionStep: step.index,
  );
}

NextStep _start(HomeSnapshot s) {
  final k = s.warmupCount;
  return NextStep(
    kind: NextStepKind.startSession,
    title: 'Sesi hari ini',
    subtitle: k == null
        ? 'Langkah 1 dari $sessionStepCount · Ulang, materi baru, temukan di '
              'ayat, tirukan qari'
        : 'Langkah 1 dari $sessionStepCount · Pemanasan, ulang $k soal',
    cta: 'Mulai sesi',
    action: NextStepAction.openSession,
    badge: '±10 mnt',
    sessionStep: 0,
  );
}

NextStep _murajaah(HomeSnapshot s) {
  final due = s.murajaahDue;
  final oldest = due
      .map((item) => item.dueOn)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final late = s.today.difference(_dateOnly(oldest)).inDays;
  return NextStep(
    kind: NextStepKind.murajaah,
    title: 'Murajaah ${murajaahSummary(due)}',
    subtitle:
        '${due.length} ayat jatuh tempo'
        '${late > 0 ? ' · $late hari terlewat' : ''}',
    cta: 'Mulai murajaah',
    action: NextStepAction.openHafalan,
    badge: '${due.length} ayat',
  );
}

NextStep _reading(HomeSnapshot s) {
  final last = s.lastRead;
  final parts = <String>[
    if (s.sessionCompleted) 'Sesi selesai ✓',
    _targetText(s),
  ];
  return NextStep(
    kind: NextStepKind.reading,
    title: last == null
        ? 'Mulai membaca'
        : '${surahCatalog[last.surah - 1].displayName} · ayat ${last.ayah}',
    subtitle: parts.join(' · '),
    cta: last == null ? 'Buka Al-Fatihah' : 'Lanjut membaca',
    action: NextStepAction.openReader,
    badge: last?.page == null ? null : 'Hal. ${last!.page}',
  );
}

String _targetText(HomeSnapshot s) {
  final left = s.reading.targetSeconds - s.reading.todaySeconds;
  if (s.reading.targetSeconds <= 0 || left <= 0) {
    return 'Target hari ini tercapai';
  }
  return '${(left / 60).ceil()} mnt lagi ke target hari ini';
}

NextStepAlt _alt(NextStepKind kind, HomeSnapshot s) {
  switch (kind) {
    case NextStepKind.reading:
      final last = s.lastRead;
      final surah = last?.surah ?? 1;
      final ayah = last?.ayah ?? 1;
      // Surah bacaan terakhir sedang diputar: buka pemutar, bukan tombol
      // jeda kedua (19-beranda.md §4).
      final playing = s.nowPlaying?.surah == surah;
      return NextStepAlt(
        eyebrow: playing ? 'DIPUTAR' : 'BACA',
        text: '${surahCatalog[surah - 1].displayName} · ayat $ayah',
        action: playing ? NextStepAction.openPlayer : NextStepAction.openReader,
      );
    case NextStepKind.murajaah:
      return NextStepAlt(
        eyebrow: 'MURAJAAH',
        text:
            '${murajaahSummary(s.murajaahDue)} · '
            '${s.murajaahDue.length} ayat',
        action: NextStepAction.openHafalan,
      );
    case NextStepKind.startSession:
      return const NextStepAlt(
        eyebrow: 'SESI HARI INI',
        text: 'Belum dimulai · ±10 mnt',
        action: NextStepAction.openSession,
      );
    case NextStepKind.resumeSession:
      final step = s.session!.step;
      return NextStepAlt(
        eyebrow: 'SESI HARI INI',
        text:
            'Langkah ${step.index + 1} dari $sessionStepCount · ${step.title}',
        action: NextStepAction.openSession,
      );
  }
}

/// "An-Naba' 1–10" untuk surah pertama yang jatuh tempo, ditambah jumlah
/// surah lain bila ada (sama dengan ringkasan Beranda lama).
String murajaahSummary(List<AyahMemorization> due) {
  final bySurah = <int, List<int>>{};
  for (final item in due) {
    bySurah.putIfAbsent(item.surah, () => []).add(item.ayah);
  }
  final first = bySurah.entries.first;
  final ayat = [...first.value]..sort();
  final name = surahCatalog[first.key - 1].displayName;
  // Word joiner (U+2060) di sekitar tanda pisah: rentang "1–10" tidak
  // dipatah menjadi "1–" / "10" saat judul turun baris.
  final range = ayat.first == ayat.last
      ? '${ayat.first}'
      : '${ayat.first}⁠–⁠${ayat.last}';
  final others = bySurah.length - 1;
  return others == 0 ? '$name $range' : '$name $range + $others surah';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
