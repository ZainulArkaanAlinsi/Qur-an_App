import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

void main() {
  test('manifest katalog memiliki 114 surah dan 6236 ayat', () {
    expect(surahCatalog, hasLength(114));
    expect(
      surahCatalog.fold<int>(0, (total, surah) => total + surah.ayahCount),
      6236,
    );
    expect(surahCatalog.first.ayahCount, 7);
    expect(surahCatalog[8].ayahCount, 129);
  });

  test('nama surah untuk tampilan tidak memuat artefak encoding', () {
    expect(surahCatalog[2].displayName, 'Ali ‘Imran');
    expect(surahCatalog[4].displayName, 'Al-Ma’idah');
  });

  test('aset Tanzil memuat 6236 baris ayat', () {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
    expect(lines, hasLength(6236));
  });

  test('nomor ayat global cocok dengan urutan sumber audio', () {
    // Nilai diverifikasi terhadap api.alquran.cloud pada 21 September 2026.
    expect(globalAyahNumber(1, 1), 1);
    expect(globalAyahNumber(2, 1), 8);
    expect(globalAyahNumber(2, 255), 262);
    expect(globalAyahNumber(9, 1), 1236);
    expect(globalAyahNumber(27, 30), 3189);
    expect(globalAyahNumber(114, 6), 6236);
    expect(() => globalAyahNumber(1, 8), throwsRangeError);
    expect(() => globalAyahNumber(115, 1), throwsRangeError);
  });
}
