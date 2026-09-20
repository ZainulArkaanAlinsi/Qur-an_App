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

  test('aset Tanzil memuat 6236 baris ayat', () {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
    expect(lines, hasLength(6236));
  });
}
