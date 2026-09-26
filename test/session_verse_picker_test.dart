import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/domain/example_words.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';

/// Pemilih ayat Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §2),
/// diuji terhadap teks Tanzil asli di repo.
void main() {
  late VerseTexts texts;
  late List<VerseWords> pool;

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
    pool = shortVerses(texts);
  });

  final marks = {
    'tanwin': (VerseMark.tanwin, {0x064B, 0x064C, 0x064D}),
    'tasydid': (VerseMark.tasydid, {0x0651}),
    'sukun': (VerseMark.sukun, {0x0652}),
  };

  group('ayat pendek', () {
    test('hanya Al-Fatihah + Juz 30, ≤ 8 kata, tanpa basmalah pembuka', () {
      expect(pool, isNotEmpty);
      for (final verse in pool) {
        expect(
          verse.surah == 1 || (verse.surah >= 78 && verse.surah <= 114),
          isTrue,
          reason: verse.key,
        );
        expect(verse.words.length, inInclusiveRange(1, 8), reason: verse.key);
        expect(verse.key, isNot('1:1'));
      }
      // Ayat 1 surah lain dihitung tanpa basmalah bawaan Tanzil.
      final ikhlas = pool.firstWhere((verse) => verse.key == '112:1');
      expect(ikhlas.words, hasLength(4));
      // Al-Fatihah 2–7 dan Juz 30, kecuali ayat > 8 kata.
      expect(pool.length, 543);
    });

    test('indeks kata sama dengan tanzilWords (lewat exampleWords)', () {
      for (final verse in pool) {
        expect(
          verse.words,
          exampleWords(
            surah: verse.surah,
            ayah: verse.ayah,
            verse: texts[verse.surah]![verse.ayah - 1],
            fatihahFirst: texts[1]!.first,
          ),
          reason: verse.key,
        );
      }
    });
  });

  group('huruf hari ini', () {
    test('28 huruf, satu code point, urut seperti materi tahap 1', () {
      expect(hijaiyahLetters, hasLength(28));
      expect({
        for (final item in hijaiyahLetters) item.codePoint,
      }, hasLength(28));
      final curriculum = File(
        'assets/learn/curriculum.json',
      ).readAsStringSync();
      final order = RegExp(r'Urutannya: ([^.]+)\.').firstMatch(curriculum)![1]!;
      expect(order.split(', '), [
        for (final item in hijaiyahLetters) item.name,
      ]);
    });

    for (var index = 0; index < 28; index++) {
      test('huruf ${index + 1}: ≥ 3 ayat, kata sorotan memuat hurufnya', () {
        final letter = hijaiyahLetters[index];
        final focus = LetterFocus(letter);
        final hits = [
          for (final verse in pool)
            if (matchingWords(verse, focus).isNotEmpty) verse,
        ];
        expect(hits.length, greaterThanOrEqualTo(3), reason: letter.name);
        for (final verse in hits) {
          for (final position in matchingWords(verse, focus)) {
            expect(
              verse.word(position).runes,
              contains(letter.codePoint),
              reason: '${verse.key} kata $position',
            );
          }
        }
        // Pemilih benar-benar menemukan ayat untuk huruf ini.
        final choice = pickVerse(
          pool: pool,
          focus: focus,
          used: const [],
          seed: index,
        );
        expect(choice, isNotNull);
        final verse = verseWords(texts, choice!.surah, choice.ayah)!;
        expect(verse.words.length, lessThanOrEqualTo(8));
        for (final position in choice.words) {
          expect(verse.word(position).runes, contains(letter.codePoint));
        }
      });
    }

    test('dicocokkan persis: ة, ى, dan hamzah tidak dihitung', () {
      const ta = LetterFocus(HijaiyahLetter('ت', 'ta'));
      const ya = LetterFocus(HijaiyahLetter('ي', 'ya'));
      const alif = LetterFocus(HijaiyahLetter('ا', 'alif'));
      const ha = LetterFocus(HijaiyahLetter('ه', 'ha'));
      expect(ta.matches('ة'), isFalse); // ة
      expect(ha.matches('ة'), isFalse);
      expect(ya.matches('ى'), isFalse); // ى
      for (final hamzah in ['أ', 'إ', 'ؤ', 'ئ', 'ٱ']) {
        expect(alif.matches(hamzah), isFalse, reason: hamzah);
      }
    });
  });

  group('tanda', () {
    for (final entry in marks.entries) {
      test('${entry.key}: ≥ 3 ayat, kata sorotan memuat tandanya', () {
        final (mark, codes) = entry.value;
        final focus = MarkFocus(mark);
        final hits = [
          for (final verse in pool)
            if (matchingWords(verse, focus).isNotEmpty) verse,
        ];
        expect(hits.length, greaterThanOrEqualTo(3));
        for (final verse in hits) {
          final matched = matchingWords(verse, focus);
          for (var position = 1; position <= verse.words.length; position++) {
            final has = verse.word(position).runes.any(codes.contains);
            expect(
              matched.contains(position),
              has,
              reason: '${verse.key} kata $position',
            );
          }
        }
      });
    }

    test('Tanzil tidak memakai U+06E1 atau U+08F0–08F2', () {
      for (final verse in pool) {
        for (final rune in verse.text.runes) {
          expect(rune == 0x06E1 || (rune >= 0x08F0 && rune <= 0x08F2), isFalse);
        }
      }
    });
  });

  group('pickVerse', () {
    test('tidak memilih ayat panjang walau ada di pool', () {
      final long = verseWords(texts, 2, 255)!;
      expect(long.words.length, greaterThan(8));
      final choice = pickVerse(
        pool: [long],
        focus: const MarkFocus(VerseMark.tanwin),
        used: const [],
        seed: 0,
      );
      expect(choice, isNull);
    });

    test('mendahulukan ayat yang belum dipakai, lalu berputar', () {
      const focus = MarkFocus(VerseMark.tanwin);
      final first = pickVerse(pool: pool, focus: focus, used: [], seed: 0)!;
      final second = pickVerse(
        pool: pool,
        focus: focus,
        used: [first.key],
        seed: 0,
      )!;
      expect(second.key, isNot(first.key));

      final partial = [
        for (final verse in pool)
          if (matchingWords(verse, focus).isNotEmpty &&
              matchingWords(verse, focus).length < verse.words.length)
            verse.key,
      ];
      // Semua sudah dipakai: yang paling lama tidak muncul.
      final rotated = pickVerse(
        pool: pool,
        focus: focus,
        used: partial,
        seed: 5,
      )!;
      expect(rotated.key, partial.first);
    });

    test('ayat sebagian didahulukan: tidak semua kata tersorot', () {
      for (var seed = 0; seed < 20; seed++) {
        final choice = pickVerse(
          pool: pool,
          focus: const MarkFocus(VerseMark.fathah),
          used: const [],
          seed: seed,
        )!;
        final verse = verseWords(texts, choice.surah, choice.ayah)!;
        expect(choice.words.length, lessThan(verse.words.length));
      }
    });

    test('simpan-muat VerseChoice', () {
      final choice = pickVerse(
        pool: pool,
        focus: const LetterFocus(HijaiyahLetter('ب', 'ba')),
        used: const [],
        seed: 3,
      )!;
      expect(VerseChoice.fromJson(choice.toJson()), choice);
      expect(VerseChoice.fromJson({'s': 1, 'a': 2, 'w': <int>[]}), isNull);
      expect(
        VerseChoice.fromJson({
          's': 1,
          'a': 2,
          'w': [1],
          'f': 'x',
        }),
        isNull,
      );
    });
  });

  group('pickExample', () {
    test('rentang words dari materi dipakai persis', () {
      final choice = pickExample(
        examples: const [
          ExampleRef(surah: 114, ayah: 1, note: 'contoh', words: [4, 4]),
        ],
        texts: texts,
        used: const [],
      )!;
      expect(choice.words, [4]);
      expect(choice.note, 'contoh');
    });

    test('contoh dengan tanda: kata dihitung dari tandanya', () {
      final choice = pickExample(
        examples: const [ExampleRef(surah: 112, ayah: 1, note: '')],
        texts: texts,
        used: const [],
        focus: const MarkFocus(VerseMark.tanwin),
      )!;
      final verse = verseWords(texts, 112, 1)!;
      expect(choice.words, [verse.words.length]);
    });

    test('contoh panjang dan rentang rusak dilewati', () {
      expect(
        pickExample(
          examples: const [
            ExampleRef(surah: 2, ayah: 255, note: '', words: [1, 1]),
            ExampleRef(surah: 112, ayah: 1, note: '', words: [5, 6]),
          ],
          texts: texts,
          used: const [],
        ),
        isNull,
      );
    });

    test('rotate: false memberi null bila semua sudah dipakai', () {
      const examples = [ExampleRef(surah: 112, ayah: 1, note: '')];
      expect(
        pickExample(
          examples: examples,
          texts: texts,
          used: const ['112:1'],
          focus: const MarkFocus(VerseMark.sukun),
          rotate: false,
        ),
        isNull,
      );
      expect(
        pickExample(
          examples: examples,
          texts: texts,
          used: const ['112:1'],
          focus: const MarkFocus(VerseMark.sukun),
        )?.key,
        '112:1',
      );
    });
  });
}
