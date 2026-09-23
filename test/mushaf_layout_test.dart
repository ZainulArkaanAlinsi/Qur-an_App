import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

final List<MushafWord> _words = [
  for (final row
      in (jsonDecode(
                File(
                  'test/fixtures/qf_mushaf_v2_pages_sample.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['words']
          as List)
    _word(row as List),
];

MushafWord _word(List row) {
  final key = (row[3] as String).split(':');
  return MushafWord(
    id: row[0] as int,
    page: row[1] as int,
    line: row[2] as int,
    surah: int.parse(key[0]),
    ayah: int.parse(key[1]),
    position: row[4] as int,
    isVerseEnd: row[5] == 'end',
    glyph: row[6] as String,
  );
}

List<String> _kinds(MushafPage page) => [
  for (final line in page.lines)
    switch (line) {
      MushafTextLine() => 'T',
      MushafSurahHeader(:final surah) => 'H$surah',
      MushafBasmalah(:final surah) => 'B$surah',
    },
];

void main() {
  test(
    'halaman 1: judul Al-Fatihah lalu 7 baris teks, tanpa basmalah terpisah',
    () {
      final page = buildMushafPage(1, _words);
      expect(_kinds(page), ['H1', 'T', 'T', 'T', 'T', 'T', 'T', 'T']);
      expect(page.isOpeningPage, isTrue);
      expect(page.verseKeys, ['1:1', '1:2', '1:3', '1:4', '1:5', '1:6', '1:7']);
    },
  );

  test('halaman 2: judul dan basmalah Al-Baqarah, 8 baris', () {
    final page = buildMushafPage(2, _words);
    expect(_kinds(page), ['H2', 'B2', 'T', 'T', 'T', 'T', 'T', 'T']);
  });

  test('halaman 3: 15 baris teks penuh', () {
    expect(_kinds(buildMushafPage(3, _words)), List.filled(15, 'T'));
  });

  test(
    'halaman 50: Ali Imran dibuka dengan judul dan basmalah di baris 1–2',
    () {
      final kinds = _kinds(buildMushafPage(50, _words));
      expect(kinds.take(2), ['H3', 'B3']);
      expect(kinds.skip(2), everyElement('T'));
    },
  );

  test('judul An-Nisa tumpah ke akhir halaman 76, basmalah di awal 77', () {
    final p76 = _kinds(buildMushafPage(76, _words));
    final p77 = _kinds(buildMushafPage(77, _words));
    expect(p76.last, 'H4');
    expect(p77.first, 'B4');
    expect(p77.skip(1), everyElement('T'));
  });

  test('At-Taubah hanya punya judul, tanpa basmalah', () {
    final kinds = _kinds(buildMushafPage(187, _words));
    expect(kinds, contains('H9'));
    expect(kinds.where((k) => k.startsWith('B')), isEmpty);
  });

  test('halaman 604: tiga surah terakhir dengan judul dan basmalah', () {
    final kinds = _kinds(buildMushafPage(604, _words));
    expect(kinds.where((k) => k.startsWith('H')), ['H112', 'H113', 'H114']);
    expect(kinds.where((k) => k.startsWith('B')), ['B112', 'B113', 'B114']);
    expect(kinds, hasLength(15));
  });

  test('kata di dalam baris urut bacaan dan baris berurutan', () {
    for (final number in [3, 50, 77, 603, 604]) {
      final page = buildMushafPage(number, _words);
      MushafWord? previous;
      for (final line in page.lines.whereType<MushafTextLine>()) {
        for (final word in line.words) {
          if (previous != null) {
            final forward =
                word.surah > previous.surah ||
                (word.surah == previous.surah &&
                    (word.ayah > previous.ayah ||
                        (word.ayah == previous.ayah &&
                            word.position > previous.position)));
            expect(forward, isTrue, reason: '$number ${word.verseKey}');
          }
          previous = word;
        }
      }
    }
  });

  test('cacat data provider di halaman 589 (84:21) ditolak', () {
    expect(
      () => buildMushafPage(589, _words),
      throwsA(
        isA<MushafLayoutException>().having(
          (e) => e.message,
          'message',
          contains('84:21'),
        ),
      ),
    );
  });

  test('baris hilang ditolak, bukan dibiarkan kosong', () {
    final withoutLine5 = _words.where((w) => !(w.page == 3 && w.line == 5));
    expect(
      () => buildMushafPage(3, withoutLine5),
      throwsA(isA<MushafLayoutException>()),
    );
  });

  test('nomor halaman di luar 1–604 ditolak', () {
    expect(
      () => buildMushafPage(0, _words),
      throwsA(isA<MushafLayoutException>()),
    );
    expect(
      () => buildMushafPage(605, _words),
      throwsA(isA<MushafLayoutException>()),
    );
  });
}
