import 'package:quran_app_2025/data/juz_repository.dart';
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
