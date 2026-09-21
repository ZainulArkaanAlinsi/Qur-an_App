import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

class QuranTextRepository {
  QuranTextRepository._();

  static final instance = QuranTextRepository._();
  static const _asset = 'assets/quran/raw/tanzil_uthmani_v1.0.2.txt';
  List<List<String>>? _surahs;
  Future<List<List<String>>>? _loading;

  Future<List<String>> versesForSurah(int surahNumber) async {
    final surahs = await _load();
    if (surahNumber < 1 || surahNumber > surahs.length) {
      throw ArgumentError.value(surahNumber, 'surahNumber');
    }
    return surahs[surahNumber - 1];
  }

  Future<List<List<String>>> _load() async {
    if (_surahs != null) return _surahs!;
    try {
      return await (_loading ??= _loadValidated());
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<List<List<String>>> _loadValidated() async {
    final raw = await rootBundle.loadString(_asset);
    final verses = await compute(_parseTanzilVerses, raw);
    const expectedVerseCount = 6236;
    if (verses.length != expectedVerseCount) {
      throw StateError(
        'Manifest tidak cocok: ${verses.length}/$expectedVerseCount ayat.',
      );
    }
    var cursor = 0;
    final grouped = <List<String>>[];
    for (final surah in surahCatalog) {
      final end = cursor + surah.ayahCount;
      if (end > verses.length) {
        throw StateError('Surah ${surah.number} melewati manifest.');
      }
      grouped.add(List.unmodifiable(verses.sublist(cursor, end)));
      cursor = end;
    }
    if (cursor != expectedVerseCount || grouped.length != 114) {
      throw StateError('Manifest surah tidak lengkap.');
    }
    _surahs = List.unmodifiable(grouped);
    return _surahs!;
  }
}

List<String> _parseTanzilVerses(String raw) => raw
    .split(RegExp(r'\r?\n'))
    .where((line) => line.isNotEmpty && !line.startsWith('#'))
    .toList(growable: false);
