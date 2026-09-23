import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';

LessonQuiz _quiz(String id) => LessonQuiz(
  id: id,
  question: 'Pertanyaan $id',
  options: const ['a', 'b', 'c', 'd'],
  answer: 1,
  explanation: 'karena b',
);

List<LessonQuiz> _bank(int count) => [
  for (var i = 1; i <= count; i++) _quiz('q$i'),
];

void main() {
  group('susunan soal berubah tiap ronde', () {
    test('urutan ronde berbeda tidak sama persis', () {
      final bank = _bank(12);
      final first = QuizSession.build(bank: bank, history: const {}, round: 1);
      final second = QuizSession.build(bank: bank, history: const {}, round: 2);

      expect(
        first.map((item) => item.id),
        isNot(second.map((item) => item.id)),
      );
      // Tetap soal yang sama, hanya urutannya berbeda.
      expect(
        first.map((item) => item.id).toSet(),
        second.map((item) => item.id).toSet(),
      );
    });

    test('ronde yang sama selalu menghasilkan susunan yang sama', () {
      final bank = _bank(8);
      final a = QuizSession.build(bank: bank, history: const {}, round: 7);
      final b = QuizSession.build(bank: bank, history: const {}, round: 7);
      expect(a.map((item) => item.id), b.map((item) => item.id));
      expect(a.first.options, b.first.options);
    });

    test('pilihan jawaban ikut diacak tanpa merusak kuncinya', () {
      final bank = [_quiz('q1')];
      var moved = 0;
      for (var round = 1; round <= 20; round++) {
        final question = QuizSession.build(
          bank: bank,
          history: const {},
          round: round,
        ).single;
        // Kunci selalu menunjuk teks yang benar, di posisi mana pun.
        expect(question.options[question.answer], 'b');
        if (question.answer != 1) moved++;
      }
      expect(moved, greaterThan(0), reason: 'kuncinya tidak pernah berpindah');
    });
  });

  group('urutan prioritas', () {
    test('yang belum pernah dijawab didahulukan', () {
      final bank = _bank(6);
      final history = {
        for (var i = 1; i <= 4; i++)
          'q$i': const QuizRecord(correct: 3, wrong: 0),
      };
      final order = QuizSession.build(
        bank: bank,
        history: history,
        round: 3,
      ).map((item) => item.id).toList();
      expect(order.take(2).toSet(), {'q5', 'q6'});
    });

    test('yang pernah salah didahulukan atas yang sudah dikuasai', () {
      final bank = _bank(4);
      final history = {
        'q1': const QuizRecord(correct: 5, wrong: 0),
        'q2': const QuizRecord(correct: 5, wrong: 0),
        'q3': const QuizRecord(correct: 0, wrong: 2),
        'q4': const QuizRecord(correct: 1, wrong: 3),
      };
      final order = QuizSession.build(
        bank: bank,
        history: history,
        round: 5,
      ).map((item) => item.id).toList();
      expect(order.take(2).toSet(), {'q3', 'q4'});
      expect(order.skip(2).toSet(), {'q1', 'q2'});
    });

    test('sudah lebih sering benar dianggap dikuasai', () {
      expect(const QuizRecord(correct: 3, wrong: 1).shaky, isFalse);
      expect(const QuizRecord(correct: 1, wrong: 1).shaky, isTrue);
      expect(const QuizRecord().neverSeen, isTrue);
      expect(
        const QuizRecord(correct: 1).answered(isCorrect: false),
        const QuizRecord(correct: 1, wrong: 1),
      );
    });
  });

  group('pagination', () {
    test('membagi soal lima per halaman', () {
      expect(QuizSession.perPage, 5);
      expect(QuizSession.pageCount(0), 0);
      expect(QuizSession.pageCount(1), 1);
      expect(QuizSession.pageCount(5), 1);
      expect(QuizSession.pageCount(6), 2);
      expect(QuizSession.pageCount(12), 3);
    });

    test('halaman terakhir boleh terisi sebagian', () {
      final questions = QuizSession.build(
        bank: _bank(7),
        history: const {},
        round: 1,
      );
      expect(QuizSession.page(questions, 0), hasLength(5));
      expect(QuizSession.page(questions, 1), hasLength(2));
      // Halaman di luar jangkauan kosong, bukan melempar.
      expect(QuizSession.page(questions, 2), isEmpty);
      expect(QuizSession.page(questions, -1), isEmpty);
    });

    test('seluruh soal muncul sekali tanpa ada yang hilang', () {
      final questions = QuizSession.build(
        bank: _bank(13),
        history: const {},
        round: 4,
      );
      final pages = QuizSession.pageCount(questions.length);
      final paged = [
        for (var page = 0; page < pages; page++)
          ...QuizSession.page(questions, page),
      ];
      expect(paged.map((item) => item.id), questions.map((item) => item.id));
      expect(paged.map((item) => item.id).toSet(), hasLength(13));
    });
  });

  group('keadaan batas', () {
    test('bank kosong menghasilkan daftar kosong', () {
      expect(
        QuizSession.build(bank: const [], history: const {}, round: 1),
        isEmpty,
      );
    });

    test('batas jumlah soal dihormati', () {
      expect(
        QuizSession.build(
          bank: _bank(20),
          history: const {},
          round: 1,
          limit: 8,
        ),
        hasLength(8),
      );
    });

    test('batas lebih besar dari bank tidak menggandakan soal', () {
      expect(
        QuizSession.build(
          bank: _bank(3),
          history: const {},
          round: 1,
          limit: 10,
        ),
        hasLength(3),
      );
    });

    test('riwayat rusak ditolak, bukan dibaca sebagai nol', () {
      expect(QuizRecord.fromJson({'b': 1, 's': 2}), isNotNull);
      expect(QuizRecord.fromJson({'b': -1, 's': 0}), isNull);
      expect(QuizRecord.fromJson({'b': '1', 's': 0}), isNull);
      expect(QuizRecord.fromJson({'s': 0}), isNull);
    });
  });
}
