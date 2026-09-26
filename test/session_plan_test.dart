import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/domain/warmup_picker.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// `buildPlan` Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §1–§2)
/// dengan kurikulum dan teks Tanzil asli.
void main() {
  late VerseTexts texts;
  late Curriculum curriculum;

  setUpAll(() {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    var cursor = 0;
    texts = {
      for (final meta in surahCatalog)
        meta.number: lines.sublist(cursor, cursor += meta.ayahCount),
    };
    curriculum = CurriculumRepository.parse(
      File('assets/learn/curriculum.json').readAsStringSync(),
    );
  });

  const today = '2026-09-26';
  Lesson lessonOf(String id) =>
      curriculum.lessons.firstWhere((lesson) => lesson.id == id);

  /// Kata yang disorot memang memuat fokusnya dan ayatnya pendek.
  void expectHonestVerse(VerseChoice verse) {
    final words = verseWords(texts, verse.surah, verse.ayah)!;
    expect(words.words.length, lessThanOrEqualTo(shortVerseMaxWords));
    expect(verse.words, isNotEmpty);
    for (final position in verse.words) {
      expect(position, inInclusiveRange(1, words.words.length));
      if (verse.focus != null) {
        expect(verse.focus!.matches(words.word(position)), isTrue);
      }
    }
  }

  group('pelajaran aktif', () {
    test('pengguna baru dari tahap 1: materi bagian pertama + satu kuis', () {
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
      );
      final lesson = lessonOf('huruf-hijaiyah');
      expect(plan.lesson?.id, lesson.id);
      expect(plan.material, lesson.pages.first);
      expect(plan.materialQuizzes, hasLength(1));
      expect(plan.materialIsPractice, isFalse);
      expect(plan.session.step, SessionStep.warmup);
      expect(plan.session.materialPage, 0);
      // Belum ada pelajaran yang dibuka: tidak ada soal ulang.
      expect(plan.warmup, isEmpty);
    });

    test('melanjutkan dari langkah pelajaran tersimpan', () {
      final lesson = lessonOf('tanwin');
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 4,
        lessonSteps: {lesson.id: 2},
      );
      expect(plan.lesson?.id, lesson.id);
      expect(plan.session.materialPage, 2);
      expect(plan.material, lesson.pages[2]);
    });

    test('bacaan habis: materi menjadi satu ronde latihan', () {
      final lesson = lessonOf('huruf-hijaiyah');
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
        lessonSteps: {lesson.id: lesson.pages.length},
      );
      expect(plan.material, isEmpty);
      expect(plan.materialIsPractice, isTrue);
      expect(plan.materialQuizzes, hasLength(QuizSession.perPage));
    });

    test('pemanasan tidak mengulang kuis materi hari ini', () {
      final lesson = lessonOf('harakat');
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 3,
        completedLessons: {'huruf-hijaiyah'},
        lessonSteps: {lesson.id: 1},
      );
      final material = {for (final quiz in plan.materialQuizzes) quiz.id};
      expect(plan.warmup.length, inInclusiveRange(warmupMin, warmupMax));
      for (final item in plan.warmup) {
        expect(material.contains(item.quiz.id), isFalse);
      }
    });
  });

  group('ayat', () {
    test('tahap 1–2 tanpa contoh: huruf hari ini di ayat pendek', () {
      for (var done = 0; done < 30; done++) {
        final plan = buildPlan(
          today: today,
          curriculum: curriculum,
          includeDrafts: false,
          texts: texts,
          startLevel: 2,
          completedSessions: done,
        );
        expect(plan.lesson?.level, 2);
        final verse = plan.verse!;
        expect(verse.focus, LetterFocus(hijaiyahLetters[done % 28]));
        expectHonestVerse(verse);
      }
    });

    test('tahap 3–5 memakai contoh pelajaran dulu', () {
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 4,
      );
      expect(plan.lesson?.id, 'tanwin');
      expect(plan.verse?.key, '112:1');
      expect(plan.verse?.focus, const MarkFocus(VerseMark.tanwin));
      expectHonestVerse(plan.verse!);
    });

    test('semua contoh sudah terpakai: ayat Juz 30 bertanda sama', () {
      for (final (level, marks) in [
        (4, {VerseMark.tanwin}),
        (5, {VerseMark.sukun, VerseMark.tasydid}),
        (3, {VerseMark.fathah, VerseMark.kasrah, VerseMark.dhammah}),
      ]) {
        for (var done = 0; done < 6; done++) {
          final plan = buildPlan(
            today: today,
            curriculum: curriculum,
            includeDrafts: false,
            texts: texts,
            startLevel: level,
            completedSessions: done,
            verseHistory: const ['1:2', '112:1', '112:2'],
          );
          final verse = plan.verse!;
          expect(['1:2', '112:1', '112:2'], isNot(contains(verse.key)));
          expect(verse.surah == 1 || verse.surah >= 78, isTrue);
          expect(marks, contains((verse.focus! as MarkFocus).mark));
          expectHonestVerse(verse);
        }
      }
    });

    test('tahap ≥ 6 (debug): contoh ber-words, lalu berputar', () {
      final lesson = lessonOf('mad-asli');
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: true,
        texts: texts,
        startLevel: 6,
      );
      expect(plan.lesson?.id, lesson.id);
      expect(plan.isDraft, isTrue);
      final first = plan.verse!;
      expect(first.focus, isNull);
      expect(first.note, isNotNull);
      expectHonestVerse(first);

      final next = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: true,
        texts: texts,
        startLevel: 6,
        verseHistory: [first.key],
      ).verse!;
      expect(next.key, isNot(first.key));
    });
  });

  group('materi draf di rilis', () {
    test('titik mulai tajwid (tahap 10, draf) tidak membuka draf', () {
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 10,
        completedLessons: {'mulai'},
        lessonSteps: {'nun-sukun-tanwin': 3, 'mad-asli': 2},
        quizHistory: {
          'mad-asli': {'mad-1': const QuizRecord(wrong: 2)},
          'huruf-hijaiyah': {'huruf-1': const QuizRecord(correct: 1)},
        },
      );
      expect(plan.lesson, isNotNull);
      expect(plan.lesson!.isPublished, isTrue);
      expect(plan.isDraft, isFalse);
      final published = {
        for (final lesson in curriculum.lessons)
          if (lesson.isPublished) lesson.id,
      };
      for (final item in plan.warmup) {
        expect(published, contains(item.lessonId));
      }
      // Contoh ayat hanya dari pelajaran terbit.
      final draftExamples = {
        for (final lesson in curriculum.lessons)
          if (!lesson.isPublished)
            for (final block in lesson.blocks)
              if (block is LessonExample && block.words != null) block.verseKey,
      };
      if (plan.verse!.focus == null) {
        expect(draftExamples, isNot(contains(plan.verse!.key)));
      }
    });

    test('sesi tersimpan dengan pelajaran draf tidak dilanjutkan', () {
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        saved: const DailySession(
          date: today,
          step: SessionStep.listenRepeat,
          lessonId: 'nun-sukun-tanwin',
          verse: VerseChoice(surah: 80, ayah: 18, words: [1, 2]),
        ),
      );
      expect(plan.lesson!.isPublished, isTrue);
      expect(plan.session.step, SessionStep.warmup);
      expect(plan.session.lessonId, plan.lesson!.id);
    });

    test('semua pelajaran terbit selesai: sesi tetap punya ayat', () {
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        completedLessons: {
          for (final lesson in curriculum.lessons)
            if (lesson.isPublished) lesson.id,
        },
      );
      expect(plan.lesson, isNull);
      expect(plan.material, isEmpty);
      expect(plan.materialQuizzes, isEmpty);
      expectHonestVerse(plan.verse!);
    });
  });

  group('lanjut dan hari berganti', () {
    test('hari yang sama: langkah dan ayat dilanjutkan', () {
      final first = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
      );
      final saved = first.session.copyWith(
        step: SessionStep.findInVerse,
        skipped: {SessionStep.warmup},
      );
      final resumed = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
        // Materi sudah maju di tengah sesi; bagian hari ini tetap sama.
        lessonSteps: {'huruf-hijaiyah': 1},
        verseHistory: [first.verse!.key],
        saved: saved,
      );
      expect(resumed.session.step, SessionStep.findInVerse);
      expect(resumed.session.skipped, {SessionStep.warmup});
      expect(resumed.verse, first.verse);
      expect(resumed.session.materialPage, 0);
    });

    test('hari berganti di tengah sesi: sesi baru untuk hari ini', () {
      final yesterday = buildPlan(
        today: '2026-09-25',
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
      ).session.copyWith(step: SessionStep.listenRepeat);
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: false,
        texts: texts,
        startLevel: 1,
        saved: yesterday,
      );
      expect(plan.session.date, today);
      expect(plan.session.step, SessionStep.warmup);
      expect(plan.session.completed, isFalse);
    });
  });

  group('pemanasan', () {
    Lesson quizLesson(String id, int count) => Lesson(
      id: id,
      level: 1,
      order: 1,
      title: id,
      summary: id,
      objectives: const [],
      blocks: [
        for (var i = 1; i <= count; i++)
          LessonQuiz(
            id: '$id-$i',
            question: 'q',
            options: const ['a', 'b'],
            answer: 0,
            explanation: 'e',
          ),
      ],
      sources: const [],
      review: ContentReviewStatus.published,
      provenance: 'tes',
    );

    test('yang pernah salah dulu, lalu yang paling lama tidak dijawab', () {
      final lesson = quizLesson('a', 6);
      final items = pickWarmup(
        opened: [lesson],
        history: {
          'a': {
            'a-1': const QuizRecord(correct: 3, lastDate: '2026-09-20'),
            'a-2': const QuizRecord(correct: 1, lastDate: '2026-09-01'),
            'a-3': const QuizRecord(
              correct: 2,
              wrong: 1,
              lastDate: '2026-09-25',
            ),
            'a-4': const QuizRecord(wrong: 1, lastDate: '2026-09-24'),
            'a-5': const QuizRecord(correct: 1),
          },
        },
      );
      expect([for (final item in items) item.quiz.id], ['a-4', 'a-3', 'a-5']);
    });

    test('3 soal, bertambah sampai 5 bila banyak yang salah', () {
      final lesson = quizLesson('b', 8);
      List<String> ids(int wrong) => [
        for (final item in pickWarmup(
          opened: [lesson],
          history: {
            'b': {
              for (var i = 1; i <= 8; i++)
                'b-$i': QuizRecord(correct: 1, wrong: i <= wrong ? 2 : 0),
            },
          },
        ))
          item.quiz.id,
      ];
      expect(ids(0), hasLength(3));
      expect(ids(4), hasLength(4));
      expect(ids(7), hasLength(5));
    });

    test('belum pernah dijawab dipakai terakhir untuk mencukupi', () {
      final lesson = quizLesson('c', 4);
      final items = pickWarmup(
        opened: [lesson],
        history: {
          'c': {'c-3': const QuizRecord(correct: 1)},
        },
      );
      expect([for (final item in items) item.quiz.id], ['c-3', 'c-1', 'c-2']);
    });
  });

  group('DailySession', () {
    test('simpan-muat', () {
      const session = DailySession(
        date: today,
        step: SessionStep.done,
        lessonId: 'tanwin',
        materialPage: 1,
        verse: VerseChoice(
          surah: 112,
          ayah: 1,
          words: [4],
          focus: MarkFocus(VerseMark.tanwin),
        ),
        completed: true,
        skipped: {SessionStep.warmup, SessionStep.findInVerse},
        rating: SelfRating.mirip,
        tomorrow: 'Latihan Tanwin',
      );
      final back = DailySession.fromJson(session.toJson())!;
      expect(back.toJson(), session.toJson());
    });

    test('gagal tertutup', () {
      expect(DailySession.fromJson('x'), isNull);
      expect(DailySession.fromJson({'tanggal': today}), isNull);
      expect(
        DailySession.fromJson({
          'tanggal': '26-09-2026',
          'langkah': 'warmup',
          'selesai': false,
        }),
        isNull,
      );
      expect(
        DailySession.fromJson({
          'tanggal': today,
          'langkah': 'warmup',
          'selesai': false,
          'ayat': {'s': 1},
        }),
        isNull,
      );
    });
  });

  test('nextTitle: bagian berikutnya, latihan, lalu pelajaran berikutnya', () {
    final lesson = lessonOf('tanwin');
    String? title(int page, Set<String> done) => nextTitle(
      curriculum: curriculum,
      includeDrafts: false,
      lesson: lesson,
      nextPage: page,
      completedLessons: done,
    );
    expect(title(1, const {}), lesson.title);
    expect(title(lesson.pages.length, const {}), 'Latihan ${lesson.title}');
    expect(
      title(lesson.stepCount, {
        'mulai',
        'huruf-hijaiyah',
        'bentuk-sambung',
        'harakat',
        'tanwin',
      }),
      lessonOf('sukun-tasydid').title,
    );
  });

  test('markForLevel dan letterForSession berputar', () {
    expect(markForLevel(4, 7), VerseMark.tanwin);
    expect(markForLevel(5, 0), VerseMark.sukun);
    expect(markForLevel(5, 1), VerseMark.tasydid);
    expect(markForLevel(3, 2), VerseMark.dhammah);
    expect(markForLevel(2, 0), isNull);
    expect(letterForSession(0).name, 'alif');
    expect(letterForSession(29).name, 'ba');
    expect(dayNumber('1970-01-02'), 1);
  });
}
