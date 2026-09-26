/// Pemanasan Sesi hari ini: 3–5 soal ulang
/// (docs/design/v5-sesi-harian/SESI_HARIAN.md §1 langkah 1).
library;

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';

/// Satu soal pemanasan beserta pelajaran asalnya (riwayat jawaban disimpan
/// per pelajaran).
@immutable
class WarmupItem {
  const WarmupItem({required this.lessonId, required this.quiz});

  final String lessonId;
  final LessonQuiz quiz;
}

/// Sedikitnya dan paling banyak soal pemanasan.
const warmupMin = 3;
const warmupMax = 5;

/// Menyusun soal pemanasan dari [opened], pelajaran yang sudah dibuka dan
/// boleh tampil (pemanggil sudah menyaring materi draf di rilis).
///
/// Urutan:
/// 1. soal yang pernah salah (yang belum dikuasai lebih dulu), lalu
/// 2. soal lain yang pernah dijawab, yang paling lama tidak dijawab dulu,
/// 3. baru soal pelajaran terbuka yang belum pernah dijawab, urut materi.
///
/// Jumlahnya [warmupMin], bertambah sampai [warmupMax] bila soal yang pernah
/// salah lebih banyak. Soal di [exclude] (mis. kuis materi baru hari ini)
/// tidak dipakai.
List<WarmupItem> pickWarmup({
  required List<Lesson> opened,
  required Map<String, Map<String, QuizRecord>> history,
  Set<String> exclude = const {},
}) {
  final wrong = <(WarmupItem, QuizRecord, int)>[];
  final answered = <(WarmupItem, QuizRecord, int)>[];
  final fresh = <WarmupItem>[];
  var order = 0;
  for (final lesson in opened) {
    final records = history[lesson.id] ?? const {};
    for (final quiz in lesson.quizzes) {
      if (exclude.contains(quiz.id)) continue;
      final item = WarmupItem(lessonId: lesson.id, quiz: quiz);
      final record = records[quiz.id] ?? const QuizRecord();
      if (record.neverSeen) {
        fresh.add(item);
      } else if (record.wrong > 0) {
        wrong.add((item, record, order));
      } else {
        answered.add((item, record, order));
      }
      order++;
    }
  }

  // Tanggal kosong (catatan lama) dianggap paling lama.
  int byAge(QuizRecord a, QuizRecord b) =>
      (a.lastDate ?? '').compareTo(b.lastDate ?? '');

  wrong.sort((a, b) {
    if (a.$2.shaky != b.$2.shaky) return a.$2.shaky ? -1 : 1;
    final age = byAge(a.$2, b.$2);
    return age != 0 ? age : a.$3.compareTo(b.$3);
  });
  answered.sort((a, b) {
    final age = byAge(a.$2, b.$2);
    return age != 0 ? age : a.$3.compareTo(b.$3);
  });

  final ordered = [
    for (final entry in wrong) entry.$1,
    for (final entry in answered) entry.$1,
    ...fresh,
  ];
  final count = wrong.length.clamp(warmupMin, warmupMax);
  return ordered.take(count).toList(growable: false);
}
