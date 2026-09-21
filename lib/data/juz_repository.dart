import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

class JuzBoundary {
  const JuzBoundary(this.number, this.surah, this.verse);
  final int number;
  final int surah;
  final int verse;
}

/// Tanzil metadata v1.0, downloaded verbatim from the official source.
class JuzRepository {
  static Future<List<JuzBoundary>> load() async =>
      parse(await rootBundle.loadString('assets/quran/raw/quran-data.xml'));

  static List<JuzBoundary> parse(String xml) {
    final entries = RegExp(r'<juz index="(\d+)" sura="(\d+)" aya="(\d+)"\s*/>')
        .allMatches(xml)
        .map(
          (m) =>
              JuzBoundary(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
        )
        .toList();
    if (entries.length != 30)
      throw const FormatException('Metadata Juz tidak lengkap.');
    var previous = 0;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.number != i + 1 ||
          entry.surah < 1 ||
          entry.surah > 114 ||
          entry.verse < 1 ||
          entry.verse > surahCatalog[entry.surah - 1].ayahCount) {
        throw const FormatException('Batas Juz tidak valid.');
      }
      final ordinal = surahCatalog
          .take(entry.surah - 1)
          .fold<int>(entry.verse, (sum, surah) => sum + surah.ayahCount);
      if (ordinal <= previous || (i == 0 && ordinal != 1)) {
        throw const FormatException('Urutan Juz tidak valid.');
      }
      previous = ordinal;
    }
    return List.unmodifiable(entries);
  }
}
