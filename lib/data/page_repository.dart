import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Awal satu halaman mushaf standar (Madinah, 604 halaman).
class PageBoundary {
  const PageBoundary(this.number, this.surah, this.verse);
  final int number;
  final int surah;
  final int verse;
}

/// Batas halaman dari metadata Tanzil v1.0, file yang sama dengan sumber batas
/// Juz.
///
/// Dipakai untuk melompat ke awal halaman; bukan untuk menyusun tata letak
/// halaman mushaf.
class PageRepository {
  static Future<List<PageBoundary>> load() async =>
      parse(await rootBundle.loadString('assets/quran/raw/quran-data.xml'));

  /// Gagal tertutup: metadata yang tidak lengkap atau tidak berurutan ditolak
  /// daripada menghasilkan navigasi yang salah.
  static List<PageBoundary> parse(String xml) {
    final entries = RegExp(r'<page index="(\d+)" sura="(\d+)" aya="(\d+)"\s*/>')
        .allMatches(xml)
        .map(
          (m) => PageBoundary(
            int.parse(m[1]!),
            int.parse(m[2]!),
            int.parse(m[3]!),
          ),
        )
        .toList();
    if (entries.length != 604) {
      throw const FormatException('Metadata halaman tidak lengkap.');
    }
    var previous = 0;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.number != i + 1 ||
          entry.surah < 1 ||
          entry.surah > 114 ||
          entry.verse < 1 ||
          entry.verse > surahCatalog[entry.surah - 1].ayahCount) {
        throw const FormatException('Batas halaman tidak valid.');
      }
      final ordinal = surahCatalog
          .take(entry.surah - 1)
          .fold<int>(entry.verse, (sum, surah) => sum + surah.ayahCount);
      if (ordinal <= previous || (i == 0 && ordinal != 1)) {
        throw const FormatException('Urutan halaman tidak valid.');
      }
      previous = ordinal;
    }
    return List.unmodifiable(entries);
  }
}
