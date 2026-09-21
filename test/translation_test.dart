import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';

String _fullFixture({String Function(int surah, int ayah)? text}) => [
  '# header',
  for (final surah in surahCatalog)
    for (var ayah = 1; ayah <= surah.ayahCount; ayah++)
      '${surah.number}|$ayah|${text?.call(surah.number, ayah) ?? 't'}',
].join('\n');

void main() {
  group('aset terjemahan Tanzil', () {
    late List<List<String>> surahs;

    setUpAll(() {
      surahs = parseTanzilTranslation(
        File(TranslationRepository.asset).readAsStringSync(),
      );
    });

    test('mencakup 114 surah sesuai manifest ayat', () {
      expect(surahs, hasLength(114));
      for (final surah in surahCatalog) {
        expect(surahs[surah.number - 1], hasLength(surah.ayahCount));
      }
    });

    test('header menyebut edisi, penerjemah, dan tanggal', () {
      final header = File(
        TranslationRepository.asset,
      ).readAsLinesSync().where((line) => line.startsWith('#')).join('\n');
      expect(header, contains('ID: id.indonesian'));
      expect(header, contains('Indonesian Ministry of Religious Affairs'));
      expect(header, contains('June 4, 2010'));
    });

    test('ayat kunci terpasang pada verseKey yang benar', () {
      expect(
        surahs[0][0],
        'Dengan menyebut nama Allah Yang Maha Pemurah lagi Maha Penyayang.',
      );
      expect(surahs[0][1], 'Segala puji bagi Allah, Tuhan semesta alam.');
      expect(surahs[113], hasLength(6));
      expect(surahs.every((s) => s.every((t) => t.trim().isNotEmpty)), isTrue);
    });
  });

  group('parser terjemahan', () {
    test('menerima akhir baris CRLF tanpa menyisakan \r', () {
      final parsed = parseTanzilTranslation(
        _fullFixture().replaceAll('\n', '\r\n'),
      );
      expect(parsed[0][0], 't');
    });

    test('teks yang memuat | tetap utuh', () {
      final parsed = parseTanzilTranslation(
        _fullFixture(text: (s, a) => s == 1 && a == 1 ? 'a|b' : 't'),
      );
      expect(parsed[0][0], 'a|b');
    });

    test('ayat ganda ditolak', () {
      expect(
        () => parseTanzilTranslation('${_fullFixture()}\n1|1|lagi'),
        throwsFormatException,
      );
    });

    test('ayat yang hilang ditolak', () {
      final missing = _fullFixture()
          .split('\n')
          .where((line) => line != '2|255|t')
          .join('\n');
      expect(() => parseTanzilTranslation(missing), throwsStateError);
    });

    test('ayat di luar manifest ditolak', () {
      expect(
        () => parseTanzilTranslation('${_fullFixture()}\n1|8|t'),
        throwsFormatException,
      );
    });

    test('baris rusak ditolak', () {
      expect(() => parseTanzilTranslation('1-1-teks'), throwsFormatException);
    });
  });
}
