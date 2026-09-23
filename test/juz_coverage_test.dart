import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/khatam/domain/juz_coverage.dart';

void main() {
  final boundaries = JuzRepository.parse(
    File('assets/quran/raw/quran-data.xml').readAsStringSync(),
  );

  test('setiap surah masuk ke setidaknya satu juz', () {
    final covered = <int>{};
    for (var juz = 1; juz <= 30; juz++) {
      covered.addAll(JuzCoverage.surahsIn(juz, boundaries));
    }
    expect(covered.length, surahCatalog.length);
  });

  test('juz 1 berisi Al-Fatihah dan Al-Baqarah yang masih berlanjut', () {
    expect(JuzCoverage.surahsIn(1, boundaries), [1, 2]);
    // Al-Baqarah membentang sampai juz 3, jadi ia ikut di ketiganya.
    expect(JuzCoverage.surahsIn(2, boundaries), contains(2));
    expect(JuzCoverage.surahsIn(3, boundaries), contains(2));
  });

  test('juz 30 berakhir di surah terakhir', () {
    final surahs = JuzCoverage.surahsIn(30, boundaries);
    expect(surahs.first, 78);
    expect(surahs.last, 114);
  });

  test('juz baru selesai bila semua surahnya selesai', () {
    // Al-Fatihah saja tidak cukup: juz 1 juga memuat Al-Baqarah.
    expect(JuzCoverage.completeJuz({1}, boundaries), isEmpty);
    expect(JuzCoverage.completeJuz({1, 2}, boundaries), contains(1));
  });

  test('juz berikutnya yang belum selesai dilaporkan', () {
    expect(JuzCoverage.nextIncomplete(const {}, boundaries), 1);
    // Al-Baqarah mengisi seluruh juz 2, jadi juz 1 dan 2 sama-sama selesai.
    expect(JuzCoverage.nextIncomplete({1, 2}, boundaries), 3);
    final all = {for (var s = 1; s <= 114; s++) s};
    expect(JuzCoverage.nextIncomplete(all, boundaries), isNull);
  });

  test('rentang halaman tiap juz berurutan dan menutup 604 halaman', () {
    final pages = PageRepository.parse(
      File('assets/quran/raw/quran-data.xml').readAsStringSync(),
    );
    expect(JuzCoverage.pageRangeFor(1, boundaries, pages), (1, 21));
    expect(JuzCoverage.pageRangeFor(30, boundaries, pages).$2, 604);

    var previousLast = 0;
    for (var juz = 1; juz <= 30; juz++) {
      final (first, last) = JuzCoverage.pageRangeFor(juz, boundaries, pages);
      expect(first, lessThanOrEqualTo(last), reason: 'juz $juz terbalik');
      // Juz berikutnya boleh mulai di halaman yang sama karena satu halaman
      // bisa memuat akhir juz lama dan awal juz baru.
      expect(first, greaterThanOrEqualTo(previousLast), reason: 'juz $juz');
      previousLast = last;
    }
  });

  test('batas juz yang tidak lengkap ditolak', () {
    expect(
      () => JuzCoverage.surahsIn(1, boundaries.take(3).toList()),
      throwsArgumentError,
    );
  });
}
