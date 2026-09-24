import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

void main() {
  late List<List<String>> tanzil;
  late TajweedRepository repository;

  setUpAll(() {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    var cursor = 0;
    tanzil = [
      for (final meta in surahCatalog)
        lines.sublist(cursor, cursor += meta.ayahCount),
    ];
    repository = TajweedRepository(
      loadAsset: () async => File(
        'assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json',
      ).readAsStringSync(),
      verses: (surah) async => tanzil[surah - 1],
    );
  });

  test('anotasi tepat di seluruh 6236 ayat teks Tanzil aplikasi', () async {
    // Patokan berupa code point, bukan huruf yang diketik.
    const alifWasl = 0x0671;
    const lam = 0x0644;
    const qalqalahLetters = {0x0642, 0x0637, 0x0628, 0x062C, 0x062F};
    var verses = 0;
    var spans = 0;
    for (final meta in surahCatalog) {
      final surah = await repository.forSurah(meta.number);
      for (var i = 0; i < surah.length; i++) {
        final verse = surah[i];
        verses++;
        // Teks tidak diubah sedikit pun.
        expect(verse.text, tanzil[meta.number - 1][i]);
        expect(verse.rejectedClasses, isEmpty, reason: verse.verseKey);
        for (final segment in verse.segments) {
          spans++;
          final first = verse.text.codeUnitAt(segment.start);
          switch (segment.rule) {
            case TajweedRule.hamzahWasl:
              expect(first, alifWasl, reason: verse.verseKey);
            case TajweedRule.lamSyamsiyah:
              expect(first, lam, reason: verse.verseKey);
            case TajweedRule.qalqalah:
              expect(qalqalahLetters, contains(first), reason: verse.verseKey);
            default:
              break;
          }
        }
      }
    }
    expect(verses, 6236);
    expect(spans, greaterThan(50000));
  });

  test('basmalah dipisah dari ayat 1 di 112 surah, bukan di 1 dan 9', () {
    final fatihah = tanzil[0][0];
    final withPrefix = [
      for (final meta in surahCatalog)
        if (basmalahPrefix(meta.number, tanzil[meta.number - 1][0], fatihah) >
            0)
          meta.number,
    ];
    expect(withPrefix, hasLength(112));
    expect(withPrefix, isNot(contains(1)));
    expect(withPrefix, isNot(contains(9)));
    // Sisa ayat 1 Al-Ikhlas adalah kata-kata ayat itu saja.
    final ikhlas = tanzil[111][0];
    final rest = ikhlas.substring(basmalahPrefix(112, ikhlas, fatihah));
    expect(rest.split(' '), hasLength(4));
  });

  test('semua hukum cpfair punya padanan', () {
    final data = File(
      'assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json',
    ).readAsStringSync();
    for (final name in cpfairRules.keys) {
      expect(data, contains('"$name"'));
    }
  });
}
