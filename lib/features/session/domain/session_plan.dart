/// Sesi hari ini: rencana satu sesi ±10 menit
/// (docs/design/v5-sesi-harian/SESI_HARIAN.md §1–§2).
///
/// [buildPlan] murni: semua masukan (kurikulum, kemajuan, riwayat) diberikan
/// pemanggil, jadi hasilnya bisa diuji tanpa layar dan tanpa penyimpanan.
library;

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/domain/warmup_picker.dart';

/// Lima langkah sesi, berurutan.
enum SessionStep {
  warmup('Pemanasan', 'Ulang'),
  newMaterial('Materi baru', 'Materi'),
  findInVerse('Temukan di ayat', 'Temukan'),
  listenRepeat('Dengar & tirukan', 'Tirukan'),
  done('Selesai', 'Selesai');

  const SessionStep(this.title, this.shortLabel);

  /// Judul langkah di layar sesi.
  final String title;

  /// Label di bawah titik penunjuk langkah.
  final String shortLabel;

  /// Langkah sesudahnya; [done] tetap [done].
  SessionStep get next => this == done ? done : SessionStep.values[index + 1];

  /// Semua langkah bisa dilewati kecuali Selesai.
  bool get skippable => this != done;

  static SessionStep? fromName(Object? name) {
    for (final step in values) {
      if (step.name == name) return step;
    }
    return null;
  }
}

/// Penilaian diri di langkah Selesai. Aplikasi tidak menilai bacaan; ini
/// hanya catatan pengguna tentang dirinya sendiri.
enum SelfRating {
  mirip('Sudah mirip'),
  beda('Masih beda');

  const SelfRating(this.label);

  final String label;

  static SelfRating? fromName(Object? name) {
    for (final rating in values) {
      if (rating.name == name) return rating;
    }
    return null;
  }
}

/// Keadaan sesi satu hari, disimpan di `sesi.hari.<yyyy-mm-dd>`.
@immutable
class DailySession {
  const DailySession({
    required this.date,
    required this.step,
    this.lessonId,
    this.materialPage,
    this.verse,
    this.completed = false,
    this.skipped = const {},
    this.rating,
    this.tomorrow,
  });

  /// Tanggal lokal yyyy-mm-dd saat sesi dimulai.
  final String date;

  /// Langkah terakhir yang dicapai; dibuka lagi dari sini pada hari yang sama.
  final SessionStep step;

  final String? lessonId;

  /// Bagian pelajaran yang menjadi materi baru hari ini (indeks halaman
  /// `Lesson.pages`; sama dengan jumlah halaman berarti bagian latihan).
  final int? materialPage;

  final VerseChoice? verse;
  final bool completed;

  /// Langkah yang dilewati, untuk ringkasan.
  final Set<SessionStep> skipped;

  final SelfRating? rating;

  /// Judul materi berikutnya ("besok: …"), diisi saat sesi selesai.
  final String? tomorrow;

  DailySession copyWith({
    SessionStep? step,
    String? lessonId,
    int? materialPage,
    VerseChoice? verse,
    bool? completed,
    Set<SessionStep>? skipped,
    SelfRating? rating,
    String? tomorrow,
  }) => DailySession(
    date: date,
    step: step ?? this.step,
    lessonId: lessonId ?? this.lessonId,
    materialPage: materialPage ?? this.materialPage,
    verse: verse ?? this.verse,
    completed: completed ?? this.completed,
    skipped: skipped ?? this.skipped,
    rating: rating ?? this.rating,
    tomorrow: tomorrow ?? this.tomorrow,
  );

  Map<String, dynamic> toJson() => {
    'tanggal': date,
    'langkah': step.name,
    if (lessonId != null) 'pelajaran': lessonId,
    if (materialPage != null) 'bagian': materialPage,
    if (verse != null) 'ayat': verse!.toJson(),
    'selesai': completed,
    if (skipped.isNotEmpty) 'dilewati': [for (final step in skipped) step.name],
    if (rating != null) 'nilai': rating!.name,
    if (tomorrow != null) 'besok': tomorrow,
  };

  /// Gagal tertutup: entri rusak dianggap tidak ada.
  static DailySession? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final date = json['tanggal'];
    final step = SessionStep.fromName(json['langkah']);
    final completed = json['selesai'];
    if (date is! String || !_date.hasMatch(date) || step == null) return null;
    if (completed is! bool) return null;
    final lessonId = json['pelajaran'];
    final page = json['bagian'];
    final verseJson = json['ayat'];
    final verse = verseJson == null ? null : VerseChoice.fromJson(verseJson);
    if (verseJson != null && verse == null) return null;
    final skipped = json['dilewati'];
    final tomorrow = json['besok'];
    return DailySession(
      date: date,
      step: step,
      lessonId: lessonId is String ? lessonId : null,
      materialPage: page is int && page >= 0 ? page : null,
      verse: verse,
      completed: completed,
      skipped: {
        if (skipped is List)
          for (final name in skipped) ?SessionStep.fromName(name),
      },
      rating: SelfRating.fromName(json['nilai']),
      tomorrow: tomorrow is String ? tomorrow : null,
    );
  }

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
}

/// Rencana sesi yang siap ditampilkan.
@immutable
class SessionPlan {
  const SessionPlan({
    required this.session,
    required this.lesson,
    required this.warmup,
    required this.material,
    required this.materialQuizzes,
  });

  /// Keadaan hari ini: baru, atau yang dilanjutkan.
  final DailySession session;

  /// Pelajaran aktif, atau null bila semua materi yang boleh tampil selesai.
  final Lesson? lesson;

  final List<WarmupItem> warmup;

  /// Blok bacaan materi baru (satu halaman pelajaran), kosong di bagian
  /// latihan atau bila tidak ada pelajaran aktif.
  final List<LessonBlock> material;

  /// Kuis sesudah materi: satu soal, atau satu ronde latihan bila bacaan
  /// pelajarannya sudah habis.
  final List<LessonQuiz> materialQuizzes;

  /// Materi hari ini adalah bagian latihan pelajaran.
  bool get materialIsPractice =>
      lesson != null && material.isEmpty && materialQuizzes.isNotEmpty;

  /// Pelajaran aktif berstatus draf (hanya mungkin di build debug).
  bool get isDraft => lesson != null && !lesson!.isPublished;

  VerseChoice? get verse => session.verse;
}

/// Nomor hari sejak 1970-01-01 untuk tanggal yyyy-mm-dd; benih yang stabil.
int dayNumber(String date) {
  final parsed = DateTime.tryParse('${date}T00:00:00Z');
  return parsed == null ? 0 : parsed.millisecondsSinceEpoch ~/ 86400000;
}

/// Tanda yang dicari di tahap 3–5 (§2 poin 3), bergiliran per sesi selesai.
VerseMark? markForLevel(int level, int completedSessions) => switch (level) {
  3 => const [
    VerseMark.fathah,
    VerseMark.kasrah,
    VerseMark.dhammah,
  ][completedSessions % 3],
  4 => VerseMark.tanwin,
  5 => const [VerseMark.sukun, VerseMark.tasydid][completedSessions % 2],
  _ => null,
};

/// Huruf hari ini (§2 poin 2): satu dari 28, maju satu setiap sesi selesai.
HijaiyahLetter letterForSession(int completedSessions) =>
    hijaiyahLetters[completedSessions % hijaiyahLetters.length];

/// Pelajaran aktif: yang pertama belum selesai mulai dari tahap titik mulai,
/// lalu yang pertama belum selesai; sama dengan tab Belajar.
Lesson? activeLesson({
  required List<Lesson> visible,
  required Set<String> completedLessons,
  int startLevel = 0,
}) {
  bool open(Lesson lesson) => !completedLessons.contains(lesson.id);
  return visible
          .where((lesson) => lesson.level >= startLevel && open(lesson))
          .firstOrNull ??
      visible.where(open).firstOrNull;
}

/// Menyusun sesi hari ini.
///
/// - [includeDrafts] false (rilis): hanya pelajaran terbit yang dipakai untuk
///   materi, pemanasan, maupun contoh ayat.
/// - [saved] dilanjutkan hanya bila tanggalnya [today] dan pelajarannya masih
///   boleh tampil. Sesi kemarin yang belum selesai tidak dibawa ke hari baru.
/// - [texts] berisi teks Tanzil Al-Fatihah, Juz 30, dan surah contoh
///   pelajaran aktif. Tanpa teks, sesi tetap tersusun tanpa ayat.
SessionPlan buildPlan({
  required String today,
  required Curriculum curriculum,
  required bool includeDrafts,
  required VerseTexts texts,
  int startLevel = 0,
  Set<String> completedLessons = const {},
  Map<String, int> lessonSteps = const {},
  Map<String, Map<String, QuizRecord>> quizHistory = const {},
  List<String> verseHistory = const [],
  int completedSessions = 0,
  DailySession? saved,
}) {
  final visible = curriculum.visible(includeDrafts: includeDrafts);
  Lesson? byId(String? id) => id == null
      ? null
      : visible.where((lesson) => lesson.id == id).firstOrNull;

  var resume = saved != null && saved.date == today ? saved : null;
  if (resume != null &&
      resume.lessonId != null &&
      byId(resume.lessonId) == null) {
    // Pelajaran tersimpan tidak boleh tampil lagi (mis. draf di rilis).
    resume = null;
  }

  final lesson = resume != null
      ? byId(resume.lessonId)
      : activeLesson(
          visible: visible,
          completedLessons: completedLessons,
          startLevel: startLevel,
        );

  final day = dayNumber(today);
  var material = const <LessonBlock>[];
  var materialQuizzes = const <LessonQuiz>[];
  int? page;
  if (lesson != null) {
    final pages = lesson.pages;
    page = (resume?.materialPage ?? lessonSteps[lesson.id] ?? 0).clamp(
      0,
      pages.length,
    );
    final bank = lesson.quizzes;
    if (page < pages.length) material = List.unmodifiable(pages[page]);
    if (bank.isNotEmpty) {
      final ids = [
        for (final question in QuizSession.build(
          bank: bank,
          history: quizHistory[lesson.id] ?? const {},
          round: day,
          limit: page < pages.length ? 1 : QuizSession.perPage,
        ))
          question.id,
      ];
      materialQuizzes = List.unmodifiable([
        for (final id in ids) bank.firstWhere((quiz) => quiz.id == id),
      ]);
    }
  }

  final opened = [
    for (final item in visible)
      if (completedLessons.contains(item.id) ||
          (lessonSteps[item.id] ?? 0) > 0 ||
          (quizHistory[item.id]?.isNotEmpty ?? false))
        item,
  ];
  final warmup = pickWarmup(
    opened: opened,
    history: quizHistory,
    exclude: {for (final quiz in materialQuizzes) quiz.id},
  );

  final verse =
      _validVerse(resume?.verse, texts) ??
      pickSessionVerse(
        lesson: lesson,
        texts: texts,
        used: verseHistory,
        completedSessions: completedSessions,
        seed: day,
      );

  final session =
      resume?.copyWith(verse: verse) ??
      DailySession(
        date: today,
        step: SessionStep.warmup,
        lessonId: lesson?.id,
        materialPage: page,
        verse: verse,
      );

  return SessionPlan(
    session: session,
    lesson: lesson,
    warmup: warmup,
    material: material,
    materialQuizzes: materialQuizzes,
  );
}

/// Ayat tersimpan hanya dipakai lagi bila masih cocok dengan teks.
VerseChoice? _validVerse(VerseChoice? verse, VerseTexts texts) {
  if (verse == null) return null;
  final words = verseWords(texts, verse.surah, verse.ayah);
  if (words == null) return null;
  return verse.words.every((word) => word <= words.words.length) ? verse : null;
}

/// Ayat untuk langkah 3–4 (§2).
///
/// 1. Tahap ≥ 6: contoh pelajaran yang punya `words`, yang belum pernah
///    muncul dulu, lalu berputar.
/// 2. Tahap 0–2 (tanpa contoh) atau tanpa pelajaran aktif: huruf hari ini di
///    ayat pendek Al-Fatihah + Juz 30.
/// 3. Tahap 3–5: contoh pelajaran dengan kata yang memuat tandanya; bila
///    semuanya sudah dipakai, ayat pendek yang memuat tanda itu.
VerseChoice? pickSessionVerse({
  required Lesson? lesson,
  required VerseTexts texts,
  required List<String> used,
  required int completedSessions,
  required int seed,
}) {
  final examples = [
    if (lesson != null)
      for (final block in lesson.blocks)
        if (block is LessonExample)
          ExampleRef(
            surah: block.surah,
            ayah: block.ayah,
            note: block.note,
            words: block.words,
          ),
  ];
  final level = lesson?.level ?? 0;
  final mark = markForLevel(level, completedSessions);
  if (mark != null) {
    final focus = MarkFocus(mark);
    return pickExample(
          examples: examples,
          texts: texts,
          used: used,
          focus: focus,
          rotate: false,
        ) ??
        pickVerse(
          pool: shortVerses(texts),
          focus: focus,
          used: used,
          seed: seed,
        );
  }
  if (level >= 6) {
    final example = pickExample(examples: examples, texts: texts, used: used);
    if (example != null) return example;
  }
  return pickVerse(
    pool: shortVerses(texts),
    focus: LetterFocus(letterForSession(completedSessions)),
    used: used,
    seed: seed,
  );
}

/// Judul untuk "besok: …" setelah materi hari ini.
///
/// [nextPage] adalah bagian pelajaran sesudah materi hari ini (sama dengan
/// langkah pelajaran yang tersimpan). Bila pelajarannya sudah selesai,
/// judulnya pelajaran berikutnya.
String? nextTitle({
  required Curriculum curriculum,
  required bool includeDrafts,
  required Lesson? lesson,
  required int nextPage,
  required Set<String> completedLessons,
  int startLevel = 0,
}) {
  if (lesson != null && !completedLessons.contains(lesson.id)) {
    final pages = lesson.pages;
    if (nextPage < pages.length) {
      for (final block in pages[nextPage]) {
        if (block is LessonText && block.heading != null) {
          return block.heading;
        }
      }
      return lesson.title;
    }
    if (lesson.quizzes.isNotEmpty) return 'Latihan ${lesson.title}';
  }
  return activeLesson(
    visible: curriculum.visible(includeDrafts: includeDrafts),
    completedLessons: {...completedLessons, ?lesson?.id},
    startLevel: startLevel,
  )?.title;
}
