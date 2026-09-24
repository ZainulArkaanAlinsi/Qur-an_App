import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';

/// Data kata QF V2 untuk 12 halaman: hanya untuk tes, tidak dibundel.
final Map<String, dynamic> _fixture =
    jsonDecode(
          File(
            'test/fixtures/qf_mushaf_v2_pages_sample.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

final List<MushafWord> _words = [
  for (final row in _fixture['words'] as List)
    () {
      final r = row as List;
      final key = (r[3] as String).split(':');
      return MushafWord(
        id: r[0] as int,
        page: r[1] as int,
        line: r[2] as int,
        surah: int.parse(key[0]),
        ayah: int.parse(key[1]),
        position: r[4] as int,
        isVerseEnd: r[5] == 'end',
        glyph: r[6] as String,
      );
    }(),
];

void main() {
  late List<List<String>> tanzil;

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
  });

  MushafComposedPage compose(int number) {
    final page = buildMushafPage(number, _words);
    return composeMushafPage(page, {
      for (final surah in {
        for (final line in page.lines)
          if (line is MushafTextLine)
            for (final word in line.words) word.surah,
      })
        surah: tanzil[surah - 1],
    }, tanzil[0][0]);
  }

  test('tanda waqaf ikut kata sebelumnya, rub hizb ikut kata sesudahnya', () {
    // Teks sintetis dengan tanda asli dari rentang Unicode tanda waqaf.
    final waqf = String.fromCharCode(0x06D6);
    final hizb = String.fromCharCode(0x06DE);
    final verse = '$hizb aa bb $waqf cc';
    final words = tanzilWords(verse);
    expect(words, hasLength(3));
    expect(verse.substring(words[0].start, words[0].end), '$hizb aa');
    expect(verse.substring(words[1].start, words[1].end), 'bb $waqf');
    expect(verse.substring(words[2].start, words[2].end), 'cc');
  });

  test('halaman fixture tersusun dengan teks Tanzil tanpa selisih', () {
    // Halaman 589 berisi cacat data provider (84:21) dan memang ditolak.
    expect(() => compose(589), throwsA(isA<MushafLayoutException>()));
    for (final number in (_fixture['pages'] as List).cast<int>()) {
      if (number == 589) continue;
      final page = compose(number);
      expect(page.rows, hasLength(mushafLineCount(number)), reason: '$number');
      // Setiap kata adalah potongan persis teks ayat Tanzil.
      for (final row in page.rows) {
        if (row is! MushafTextRow) continue;
        for (final item in row.items) {
          if (item is! MushafWordItem) continue;
          final text = page.textOf(item);
          expect(text.trim(), text, reason: '$number ${item.verseKey}');
          expect(text, isNotEmpty);
        }
      }
    }
  });

  test('halaman 604: tiga surah, basmalah terpisah, 15 baris', () {
    final page = compose(604);
    expect(page.surahs, [112, 113, 114]);
    expect(page.rows.whereType<MushafHeaderRow>().map((r) => r.surah), [
      112,
      113,
      114,
    ]);
    expect(page.rows.whereType<MushafBasmalahRow>(), hasLength(3));
    // Kata pertama Al-Ikhlas adalah kata pertama ayat 1 setelah basmalah.
    final first = page.firstItem! as MushafWordItem;
    final ayah1 = tanzil[111][0];
    expect(page.textOf(first), ayah1.split(' ')[4]);
  });

  test('posisi kata di luar teks ditolak, bukan ditebak', () {
    final page = buildMushafPage(604, _words);
    final line = page.lines.whereType<MushafTextLine>().first;
    final word = line.words.first;
    final broken = MushafPage(604, [
      MushafTextLine(1, [
        MushafWord(
          id: word.id,
          page: 604,
          line: 1,
          surah: word.surah,
          ayah: word.ayah,
          position: 99,
          isVerseEnd: false,
          glyph: word.glyph,
        ),
      ]),
    ]);
    expect(
      () => composeMushafPage(broken, {112: tanzil[111]}, tanzil[0][0]),
      throwsA(isA<MushafLayoutException>()),
    );
  });
}
