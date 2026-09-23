import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Naik setiap kali kemajuan belajar berubah, supaya peta jalur dan Beranda
/// ikut menyegarkan diri tanpa saling mengenal.
final learnRevision = ValueNotifier<int>(0);

/// Satu blok isi pelajaran.
///
/// Sengaja berupa blok, bukan satu gumpalan teks: pelajaran untuk orang yang
/// belum bisa membaca harus satu konsep per blok, dan contoh ayat harus bisa
/// diambil dari dataset alih-alih diketik ke dalam materi.
@immutable
sealed class LessonBlock {
  const LessonBlock();
}

/// Penjelasan biasa.
@immutable
class LessonText extends LessonBlock {
  const LessonText(this.text);
  final String text;
}

/// Catatan pendek yang perlu ditonjolkan.
@immutable
class LessonTip extends LessonBlock {
  const LessonTip(this.text);
  final String text;
}

/// Contoh ayat. Hanya rujukannya yang disimpan; teks Arabnya diambil dari
/// dataset Tanzil supaya tidak ada ayat yang diketik ulang ke dalam materi.
@immutable
class LessonExample extends LessonBlock {
  const LessonExample({
    required this.surah,
    required this.ayah,
    required this.note,
  });

  final int surah;
  final int ayah;

  /// Keterangan penyusun materi, mis. bagian mana yang dimaksud.
  final String note;

  String get verseKey => '$surah:$ayah';
}

/// Contoh bunyi. Rekamannya wajib suara manusia yang berizin; selama belum
/// ada, bloknya tetap tampil dengan keadaan jujur "sedang disiapkan" dan tidak
/// pernah diisi TTS atau suara buatan (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
@immutable
class LessonAudio extends LessonBlock {
  const LessonAudio({required this.label, required this.asset});

  final String label;

  /// Berkas audio, atau null bila rekamannya belum ada.
  final String? asset;

  bool get isReady => asset != null && asset!.trim().isNotEmpty;
}

/// Soal pilihan ganda. Bukan penilaian bacaan — hanya memeriksa pemahaman.
@immutable
class LessonQuiz extends LessonBlock {
  const LessonQuiz({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  final String question;
  final List<String> options;

  /// Indeks jawaban benar di dalam [options].
  final int answer;

  /// Alasan jawabannya benar, ditampilkan setelah dijawab.
  final String explanation;
}

/// Rujukan tempat materi ini disusun.
@immutable
class LessonSource {
  const LessonSource({
    required this.title,
    required this.author,
    required this.url,
  });

  final String title;
  final String author;
  final String url;
}

/// Satu tahap pada jalur belajar.
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.level,
    required this.order,
    required this.title,
    required this.summary,
    required this.objectives,
    required this.blocks,
    required this.sources,
    required this.review,
    required this.provenance,
    this.rule,
  });

  final String id;

  /// Tahap ke berapa pada jalur (0 = mulai, 16 = bacaan gharib).
  final int level;

  /// Urutan di dalam tahap yang sama.
  final int order;

  final String title;
  final String summary;

  /// Apa yang bisa dilakukan setelah pelajaran ini selesai.
  final List<String> objectives;

  final List<LessonBlock> blocks;
  final List<LessonSource> sources;
  final ContentReviewStatus review;

  /// Dari mana teks pelajaran ini berasal, apa adanya. Dipakai supaya materi
  /// yang belum diperiksa tidak pernah tampak seolah sudah bersumber kitab.
  final String provenance;

  /// Hukum tajwid yang dijelaskan, bila pelajaran ini memang tentang satu
  /// hukum. Tahap awal (huruf, harakat) tidak punya.
  final TajweedRule? rule;

  /// Hanya materi terbit yang boleh tampil di rilis
  /// (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
  bool get isPublished => review == ContentReviewStatus.published;

  /// Ada isinya yang bisa dibaca, bukan sekadar kerangka.
  bool get hasContent => blocks.isNotEmpty;

  List<LessonQuiz> get quizzes => [
    for (final block in blocks)
      if (block is LessonQuiz) block,
  ];
}

/// Seluruh jalur belajar, urut tahap.
@immutable
class Curriculum {
  const Curriculum({required this.lessons});

  final List<Lesson> lessons;

  /// Materi yang boleh tampil: terbit saja di rilis, semuanya di debug.
  List<Lesson> visible({required bool includeDrafts}) => [
    for (final lesson in lessons)
      if (includeDrafts || lesson.isPublished) lesson,
  ];

  /// Pelajaran berikutnya yang belum diselesaikan, atau null bila sudah habis.
  Lesson? nextAfter(Set<String> completedIds, {required bool includeDrafts}) {
    for (final lesson in visible(includeDrafts: includeDrafts)) {
      if (!completedIds.contains(lesson.id)) return lesson;
    }
    return null;
  }

  /// Berapa yang sudah diselesaikan dari yang boleh tampil.
  int completedCount(Set<String> completedIds, {required bool includeDrafts}) {
    var done = 0;
    for (final lesson in visible(includeDrafts: includeDrafts)) {
      if (completedIds.contains(lesson.id)) done++;
    }
    return done;
  }
}
