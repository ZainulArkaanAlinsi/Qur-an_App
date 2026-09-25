import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/example_words.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';

/// `words` pada contoh ayat (docs/design/v3/DESIGN.md §6): indeks kata
/// 1-based yang dihitung persis seperti `tanzilWords()` di mushaf.
void main() {
  late List<List<String>> tanzil;
  late String curriculumRaw;

  setUpAll(() {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    var cursor = 0;
    tanzil = [
      for (final meta in surahCatalog)
        lines.sublist(cursor, cursor += meta.ayahCount),
    ];
    curriculumRaw = File('assets/learn/curriculum.json').readAsStringSync();
  });

  List<TanzilWord> wordsOf(int surah, int ayah) => exampleWords(
    surah: surah,
    ayah: ayah,
    verse: tanzil[surah - 1][ayah - 1],
    fatihahFirst: tanzil[0][0],
  );

  int? countOf(int surah, int ayah) => wordsOf(surah, ayah).length;

  String highlighted(LessonExample example) {
    final range = highlightOf(
      wordsOf(example.surah, example.ayah),
      example.words,
    );
    expect(range, isNotNull, reason: example.verseKey);
    return tanzil[example.surah - 1][example.ayah - 1].substring(
      range!.start,
      range.end,
    );
  }

  List<(int, LessonExample)> examplesWithWords(Curriculum curriculum) => [
    for (final lesson in curriculum.lessons)
      for (final block in lesson.blocks)
        if (block is LessonExample && block.words != null)
          (lesson.level, block),
  ];

  group('curriculum.json', () {
    test('semua words valid terhadap teks Tanzil', () {
      // Melempar FormatException bila ada kata di luar jangkauan ayat.
      final curriculum = CurriculumRepository.parse(
        curriculumRaw,
        wordCount: countOf,
      );
      final examples = examplesWithWords(curriculum);
      expect(examples, hasLength(191));
      for (final (_, example) in examples) {
        expect(highlighted(example).trim(), isNotEmpty);
      }
    });

    test('kata yang disorot sama dengan kata tebal di naskah peninjau', () {
      // docs/content/tajwid/NN-*.md menebalkan kata yang dimaksud. Tanda
      // waqaf ikut kata sebelumnya di aplikasi (seperti mushaf), jadi
      // tanda itu diabaikan saat membandingkan.
      final marks = RegExp('[ۖ-۞۩ۭ]');
      String bare(String text) =>
          text.replaceAll(marks, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final block = RegExp(
        r'\*\*Contoh — QS [^\n]*?(\d+):(\d+)\*\*\s*\n\s*\n'
        r'<p dir="rtl" lang="ar">(.*?)</p>',
      );
      final bold = RegExp(r'\*\*(.*?)\*\*');
      final curriculum = CurriculumRepository.parse(curriculumRaw);
      final byLevel = <int, List<LessonExample>>{};
      for (final (level, example) in examplesWithWords(curriculum)) {
        byLevel.putIfAbsent(level, () => []).add(example);
      }
      var compared = 0;
      for (final MapEntry(key: level, value: examples) in byLevel.entries) {
        final doc = Directory('docs/content/tajwid')
            .listSync()
            .whereType<File>()
            .firstWhere(
              (file) => file.uri.pathSegments.last.startsWith(
                level.toString().padLeft(2, '0'),
              ),
            );
        final expected = [
          for (final match in block.allMatches(doc.readAsStringSync()))
            if (bold.hasMatch(match.group(3)!))
              (
                '${match.group(1)}:${match.group(2)}',
                bare(
                  bold
                      .allMatches(match.group(3)!)
                      .map((m) => m.group(1))
                      .join(' '),
                ),
              ),
        ];
        expect(expected, hasLength(examples.length), reason: doc.path);
        for (var i = 0; i < examples.length; i++) {
          expect(
            (examples[i].verseKey, bare(highlighted(examples[i]))),
            expected[i],
            reason: '${doc.path} contoh ke-${i + 1}',
          );
          compared++;
        }
      }
      expect(compared, 191);
    });

    test('tahap 6–16 tetap draf', () {
      // Materi tajwid baru wajib 2 peninjau bersanad sebelum terbit
      // (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
      for (final lesson in CurriculumRepository.parse(curriculumRaw).lessons) {
        if (lesson.level >= 6) {
          expect(lesson.isPublished, isFalse, reason: lesson.id);
        }
      }
    });
  });

  group('parser words', () {
    String doc(Object? words, {int surah = 2, int ayah = 85}) => jsonEncode({
      'version': 1,
      'lessons': [
        {
          'id': 'uji',
          'level': 10,
          'order': 1,
          'title': 'Uji',
          'summary': 'Uji words.',
          'review': 'draft',
          'provenance': 'Data uji.',
          'blocks': [
            {
              'type': 'example',
              'surah': surah,
              'ayah': ayah,
              'note': 'Uji',
              'words': ?words,
            },
          ],
        },
      ],
    });

    LessonExample parse(Object? words, {int surah = 2, int ayah = 85}) =>
        CurriculumRepository.parse(
              doc(words, surah: surah, ayah: ayah),
              wordCount: countOf,
            ).lessons.single.blocks.single
            as LessonExample;

    test('words opsional; parser lama tetap membaca contoh tanpa words', () {
      expect(parse(null).words, isNull);
      expect(parse([38, 38]).words, [38, 38]);
    });

    test('words di luar jangkauan kata ayat ditolak', () {
      final count = wordsOf(2, 85).length;
      expect(() => parse([count, count + 1]), throwsFormatException);
      expect(() => parse([count + 1, count + 1]), throwsFormatException);
      expect(parse([count, count]).words, [count, count]);
    });

    test('bentuk words yang salah ditolak', () {
      for (final bad in [
        [0, 1],
        [3, 2],
        [1],
        [1, 2, 3],
        'satu',
        [1.5, 2],
      ]) {
        expect(() => parse(bad), throwsFormatException, reason: '$bad');
      }
    });

    test('indeks memakai tanzilWords: tanda waqaf ikut kata sebelumnya', () {
      // 2:85 kata ke-38 adalah ad-dunyā (izhar mutlak: nun sukun lalu ya
      // dalam satu kata), diikuti tanda waqaf yang ikut kata itu.
      final example = parse([38, 38]);
      final text = highlighted(example);
      expect(text, contains('نْي'), reason: 'nun sukun + ya');
      expect(text, endsWith('ۖ'), reason: 'tanda waqaf ikut kata');
      expect(text.split(' '), hasLength(2), reason: 'kata + tanda waqaf');
      // Sama dengan hitungan mushaf untuk ayat itu.
      expect(
        wordsOf(2, 85),
        tanzilWords(tanzil[1][84]),
        reason: 'ayat selain ayat 1 tidak punya awalan basmalah',
      );
    });

    test('ayat 1 menghitung kata sesudah basmalah bawaan Tanzil', () {
      // 112:1 (empat kata) didahului basmalah di teks Tanzil.
      final verse = tanzil[111][0];
      final example = parse([1, 1], surah: 112, ayah: 1);
      expect(wordsOf(112, 1), hasLength(4));
      expect(tanzilWords(verse), hasLength(8), reason: '4 basmalah + 4 ayat');
      expect(highlighted(example), tanzilWords(verse)[4].let(verse));
    });
  });

  test('huruf penentu diambil dari huruf Arab di dalam kurung', () {
    const withLetter = LessonExample(
      surah: 80,
      ayah: 18,
      note: 'Kata ke-1 dan ke-2: nun sukun bertemu hamzah (أ) — jelas.',
    );
    const without = LessonExample(
      surah: 2,
      ayah: 85,
      note: 'Kata ad-dunyā (izhar mutlak) dibaca jelas.',
    );
    expect(withLetter.keyLetter, 'أ');
    expect(without.keyLetter, isNull);
  });
}

extension on TanzilWord {
  String let(String verse) => verse.substring(start, end);
}
