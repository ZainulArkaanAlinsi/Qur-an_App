import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Indonesian translation bundled offline, stored verbatim from Tanzil.
///
/// Edition `id.indonesian` ("Bahasa Indonesia"), translator: Indonesian
/// Ministry of Religious Affairs, last updated 4 June 2010 per the file
/// header. Tanzil permits non-commercial use only; see
/// docs/DATASET_ATTRIBUTION.md.
class TranslationRepository {
  TranslationRepository._();
  static final instance = TranslationRepository._();
  static const asset = 'assets/quran/raw/tanzil_id.indonesian_2010-06-04.txt';

  List<List<String>>? _surahs;
  Future<List<List<String>>>? _loading;

  Future<List<String>> forSurah(int surah) async {
    final surahs = await _load();
    if (surah < 1 || surah > surahs.length) {
      throw ArgumentError.value(surah, 'surah');
    }
    return surahs[surah - 1];
  }

  Future<List<List<String>>> _load() async {
    if (_surahs != null) return _surahs!;
    try {
      return _surahs ??= await (_loading ??= rootBundle
          .loadString(asset)
          .then((raw) => compute(parseTanzilTranslation, raw)));
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }
}

/// Parses Tanzil `surah|ayah|text` lines keyed by verse, rejecting
/// duplicates, gaps and counts that differ from the surah manifest. Text is
/// kept exactly as published.
List<List<String>> parseTanzilTranslation(String raw) {
  final bySurah = [
    for (final surah in surahCatalog)
      List<String?>.filled(surah.ayahCount, null),
  ];
  var count = 0;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final first = line.indexOf('|');
    final second = first < 0 ? -1 : line.indexOf('|', first + 1);
    if (second < 0) {
      throw FormatException('Baris terjemahan tidak valid.', line);
    }
    final surah = int.tryParse(line.substring(0, first));
    final ayah = int.tryParse(line.substring(first + 1, second));
    if (surah == null || ayah == null) {
      throw FormatException('Nomor surah/ayat tidak valid.', line);
    }
    if (surah < 1 || surah > bySurah.length) {
      throw FormatException('Surah di luar manifest.', line);
    }
    final verses = bySurah[surah - 1];
    if (ayah < 1 || ayah > verses.length) {
      throw FormatException('Ayat di luar manifest.', line);
    }
    if (verses[ayah - 1] != null) {
      throw FormatException('Ayat ganda $surah:$ayah.', line);
    }
    verses[ayah - 1] = line.substring(second + 1);
    count++;
  }
  const expected = 6236;
  if (count != expected) {
    throw StateError('Terjemahan tidak lengkap: $count/$expected ayat.');
  }
  return List.unmodifiable([
    for (final verses in bySurah) List<String>.unmodifiable(verses),
  ]);
}
