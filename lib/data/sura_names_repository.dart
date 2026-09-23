import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Nama Arab tiap surah, diambil apa adanya dari metadata Tanzil v1.0.
///
/// Dipakai untuk bingkai judul di pembaca. Namanya tidak pernah diketik ulang
/// di dalam kode.
class SuraNamesRepository {
  static Future<List<String>> load() async =>
      parse(await rootBundle.loadString('assets/quran/raw/quran-data.xml'));

  /// Gagal tertutup: daftar yang tidak lengkap ditolak daripada menampilkan
  /// nama surah yang salah.
  static List<String> parse(String xml) {
    final names = RegExp(
      r'<sura index="(\d+)"[^>]*\bname="([^"]+)"',
    ).allMatches(xml).toList();
    if (names.length != surahCatalog.length) {
      throw const FormatException('Nama surah tidak lengkap.');
    }
    for (var i = 0; i < names.length; i++) {
      if (int.parse(names[i][1]!) != i + 1) {
        throw const FormatException('Urutan nama surah tidak valid.');
      }
    }
    return List.unmodifiable([for (final match in names) match[2]!]);
  }
}
