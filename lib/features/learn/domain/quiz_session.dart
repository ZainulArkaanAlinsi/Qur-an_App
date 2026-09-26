import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';

/// Catatan jawaban satu soal.
@immutable
class QuizRecord {
  const QuizRecord({this.correct = 0, this.wrong = 0, this.lastDate});

  final int correct;
  final int wrong;

  /// Tanggal lokal (yyyy-mm-dd) terakhir dijawab, atau null untuk catatan
  /// lama yang belum menyimpannya. Dipakai pemanasan Sesi hari ini: soal yang
  /// paling lama tidak dijawab didahulukan.
  final String? lastDate;

  bool get neverSeen => correct == 0 && wrong == 0;

  /// Selama jumlah salah menyamai atau melebihi benar, soalnya dianggap belum
  /// dikuasai dan perlu lebih sering muncul.
  bool get shaky => wrong > 0 && wrong >= correct;

  /// [on] (yyyy-mm-dd) menjadi [lastDate]; tanpa itu tanggal lama dipakai.
  QuizRecord answered({required bool isCorrect, String? on}) => QuizRecord(
    correct: correct + (isCorrect ? 1 : 0),
    wrong: wrong + (isCorrect ? 0 : 1),
    lastDate: on ?? lastDate,
  );

  Map<String, dynamic> toJson() => {
    'b': correct,
    's': wrong,
    if (lastDate != null) 't': lastDate,
  };

  static QuizRecord? fromJson(Map<String, dynamic> json) {
    final correct = json['b'];
    final wrong = json['s'];
    if (correct is! int || wrong is! int || correct < 0 || wrong < 0) {
      return null;
    }
    final last = json['t'];
    return QuizRecord(
      correct: correct,
      wrong: wrong,
      lastDate: last is String && _date.hasMatch(last) ? last : null,
    );
  }

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  bool operator ==(Object other) =>
      other is QuizRecord &&
      other.correct == correct &&
      other.wrong == wrong &&
      other.lastDate == lastDate;

  @override
  int get hashCode => Object.hash(correct, wrong, lastDate);
}

/// Satu soal siap tampil: pilihannya sudah diacak, dan indeks jawaban benar
/// ikut dipindahkan mengikuti acakan itu.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;

  bool isCorrect(int picked) => picked == answer;
}

/// Menyusun satu ronde latihan.
///
/// Tiga hal yang membuat soalnya tidak itu-itu saja:
/// 1. urutan soal diacak dari nomor ronde, jadi tiap ronde berbeda;
/// 2. soal yang belum pernah dijawab didahulukan, lalu yang pernah salah, baru
///    yang sudah dikuasai — supaya latihan condong ke yang belum bisa;
/// 3. urutan pilihan jawaban ikut diacak, jadi jawabannya tidak bisa dihafal
///    dari posisinya.
///
/// Semuanya ditentukan nomor ronde sehingga hasilnya bisa diulang dan diuji;
/// tidak ada keacakan yang tak terlacak.
abstract final class QuizSession {
  /// Banyaknya soal per halaman.
  static const perPage = 5;

  /// Menyusun daftar soal untuk satu ronde.
  ///
  /// [limit] membatasi jumlah soal; null berarti seluruh bank soal dipakai.
  static List<QuizQuestion> build({
    required List<LessonQuiz> bank,
    required Map<String, QuizRecord> history,
    required int round,
    int? limit,
  }) {
    if (bank.isEmpty) return const [];

    final fresh = <LessonQuiz>[];
    final shaky = <LessonQuiz>[];
    final known = <LessonQuiz>[];
    for (final quiz in bank) {
      final record = history[quiz.id] ?? const QuizRecord();
      if (record.neverSeen) {
        fresh.add(quiz);
      } else if (record.shaky) {
        shaky.add(quiz);
      } else {
        known.add(quiz);
      }
    }

    final random = Random(round);
    for (final bucket in [fresh, shaky, known]) {
      bucket.shuffle(random);
    }

    final ordered = [...fresh, ...shaky, ...known];
    final taken = limit == null || limit >= ordered.length
        ? ordered
        : ordered.take(limit).toList();

    return [for (final quiz in taken) _shuffleOptions(quiz, round)];
  }

  /// Berapa halaman untuk [count] soal.
  static int pageCount(int count) =>
      count == 0 ? 0 : (count + perPage - 1) ~/ perPage;

  /// Soal pada halaman ke-[page] (mulai dari 0).
  static List<QuizQuestion> page(List<QuizQuestion> questions, int page) {
    final start = page * perPage;
    if (start < 0 || start >= questions.length) return const [];
    return questions.sublist(start, min(start + perPage, questions.length));
  }

  /// Satu soal siap tampil dengan pilihan teracak dari nomor [round]. Dipakai
  /// Sesi hari ini, yang menyusun urutan soalnya sendiri.
  static QuizQuestion ask(LessonQuiz quiz, int round) =>
      _shuffleOptions(quiz, round);

  /// Mengacak urutan pilihan sambil menjaga jawaban benar tetap benar.
  static QuizQuestion _shuffleOptions(LessonQuiz quiz, int round) {
    // Benih per soal, supaya dua soal pada ronde yang sama tidak teracak
    // dengan pola yang sama persis.
    final random = Random(round * 31 + quiz.id.hashCode);
    final indexes = List.generate(quiz.options.length, (index) => index)
      ..shuffle(random);
    return QuizQuestion(
      id: quiz.id,
      question: quiz.question,
      options: [for (final index in indexes) quiz.options[index]],
      answer: indexes.indexOf(quiz.answer),
      explanation: quiz.explanation,
    );
  }
}
