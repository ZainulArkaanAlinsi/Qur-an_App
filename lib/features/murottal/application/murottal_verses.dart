import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';

/// Teks ayat untuk layar Murottal, dari loader yang sama dengan pembaca
/// (`ReaderScreen._load`): Tanzil Uthmani 1.0.2 + terjemahan Kemenag yang
/// dibundel. Tidak memuat dari jaringan dan tidak mengubah teks.
@immutable
class MurottalVerses {
  const MurottalVerses({required this.arabic, this.translation});

  /// Ayat 1..n; basmalah di awal ayat 1 dipotong seperti di pembaca.
  final List<String> arabic;

  /// Null bila terjemahan gagal dimuat atau jumlahnya tidak cocok.
  final List<String>? translation;

  String arabicOf(int ayah) => arabic[ayah - 1];
  String? translationOf(int ayah) => translation?[ayah - 1];

  static Future<MurottalVerses> load(int surah) async {
    final verses = await QuranTextRepository.instance.versesForSurah(surah);
    final fatihah = await QuranTextRepository.instance.versesForSurah(1);
    final split = splitBasmalah(surah, verses, fatihah.first);
    List<String>? translation;
    try {
      translation = await TranslationRepository.instance.forSurah(surah);
      if (translation.length != verses.length) translation = null;
    } on Object {
      // Terjemahan pelengkap: ayat tetap tampil tanpa terjemahan.
      translation = null;
    }
    return MurottalVerses(arabic: split.verses, translation: translation);
  }
}
