import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Menghubungkan tanda "surah selesai" dengan juz.
///
/// Aplikasi hanya mencatat penyelesaian per surah (`completed_surahs`), bukan
/// per ayat atau per halaman. Karena itu satu juz baru dinyatakan selesai bila
/// **seluruh surah yang menyinggungnya** sudah ditandai selesai: batas bawah
/// yang jujur, bukan perkiraan. Layar yang memakainya wajib menjelaskan aturan
/// ini kepada pengguna.
abstract final class JuzCoverage {
  /// Nomor surah yang sebagian atau seluruh ayatnya berada di [juz].
  static List<int> surahsIn(int juz, List<JuzBoundary> boundaries) {
    if (boundaries.length != 30) {
      throw ArgumentError('Batas juz harus lengkap 30.');
    }
    if (juz < 1 || juz > 30) throw RangeError.range(juz, 1, 30);
    final start = boundaries[juz - 1];
    final int lastSurah;
    if (juz == 30) {
      lastSurah = surahCatalog.length;
    } else {
      final next = boundaries[juz];
      // Juz berikutnya mulai di tengah surah: surah itu masih menyentuh juz
      // ini. Kalau mulai di ayat 1, surah itu sepenuhnya milik juz berikutnya.
      lastSurah = next.verse > 1 ? next.surah : next.surah - 1;
    }
    return [for (var s = start.surah; s <= lastSurah; s++) s];
  }

  /// Juz yang seluruh surahnya sudah ditandai selesai.
  static Set<int> completeJuz(
    Set<int> completedSurahs,
    List<JuzBoundary> boundaries,
  ) => {
    for (var juz = 1; juz <= 30; juz++)
      if (surahsIn(juz, boundaries).every(completedSurahs.contains)) juz,
  };

  /// Nomor ayat global (1..6236) untuk posisi surah:ayat.
  static int _ordinal(int surah, int verse) => surahCatalog
      .take(surah - 1)
      .fold<int>(verse, (sum, item) => sum + item.ayahCount);

  /// Rentang halaman mushaf yang ditempati [juz], dihitung dari batas Tanzil.
  ///
  /// Berguna untuk memberi tahu "juz ini ada di halaman berapa" tanpa
  /// mengarang perkiraan waktu baca.
  static (int first, int last) pageRangeFor(
    int juz,
    List<JuzBoundary> juzBoundaries,
    List<PageBoundary> pages,
  ) {
    if (juzBoundaries.length != 30) {
      throw ArgumentError('Batas juz harus lengkap 30.');
    }
    if (pages.isEmpty) throw ArgumentError('Batas halaman kosong.');
    if (juz < 1 || juz > 30) throw RangeError.range(juz, 1, 30);

    final start = juzBoundaries[juz - 1];
    final startOrdinal = _ordinal(start.surah, start.verse);
    final endOrdinal = juz == 30
        ? surahCatalog.fold<int>(0, (sum, item) => sum + item.ayahCount)
        : _ordinal(juzBoundaries[juz].surah, juzBoundaries[juz].verse) - 1;

    var first = pages.first.number;
    var last = pages.first.number;
    for (final page in pages) {
      final ordinal = _ordinal(page.surah, page.verse);
      if (ordinal <= startOrdinal) first = page.number;
      if (ordinal <= endOrdinal) last = page.number;
    }
    return (first, last);
  }

  /// Juz terkecil yang belum selesai, atau null bila semuanya sudah selesai.
  static int? nextIncomplete(
    Set<int> completedSurahs,
    List<JuzBoundary> boundaries,
  ) {
    final done = completeJuz(completedSurahs, boundaries);
    for (var juz = 1; juz <= 30; juz++) {
      if (!done.contains(juz)) return juz;
    }
    return null;
  }
}
