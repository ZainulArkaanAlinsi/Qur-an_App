import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Nama hukum cpfair/quran-tajweed → [TajweedRule]. Pemetaan mad masih draf
/// (docs/RELIGIOUS_CONTENT_GOVERNANCE.md): `madd_246` (mad 'aridh/lin, 2/4/6)
/// dikelompokkan ke Mad Jaiz seperti pedoman warna LPMQ.
const cpfairRules = <String, TajweedRule>{
  'hamzat_wasl': TajweedRule.hamzahWasl,
  'lam_shamsiyyah': TajweedRule.lamSyamsiyah,
  'silent': TajweedRule.silent,
  'madd_2': TajweedRule.madThabii,
  'madd_246': TajweedRule.madJaiz,
  'madd_munfasil': TajweedRule.madJaiz,
  'madd_muttasil': TajweedRule.madWajib,
  'madd_6': TajweedRule.madLazim,
  'qalqalah': TajweedRule.qalqalah,
  'ikhfa': TajweedRule.ikhfaHaqiqi,
  'ikhfa_shafawi': TajweedRule.ikhfaSyafawi,
  'idghaam_ghunnah': TajweedRule.idghamBighunnah,
  'idghaam_no_ghunnah': TajweedRule.idghamBilaghunnah,
  'idghaam_shafawi': TajweedRule.idghamMimi,
  'idghaam_mutajanisayn': TajweedRule.idghamMutajanisain,
  'idghaam_mutaqaribayn': TajweedRule.idghamMutaqaribain,
  'iqlab': TajweedRule.iqlab,
  'ghunnah': TajweedRule.ghunnah,
};

/// Anotasi tajwid offline (cpfair/quran-tajweed, CC BY 4.0) yang indeksnya
/// sudah dipetakan ke teks Tanzil aplikasi (tool/build_tajweed_asset.dart).
/// Teks ayat yang dikembalikan persis teks Tanzil, tanpa perubahan.
class TajweedRepository {
  TajweedRepository({
    Future<String> Function()? loadAsset,
    Future<List<String>> Function(int surah)? verses,
  }) : _loadAsset = loadAsset ?? (() => rootBundle.loadString(_asset)),
       _verses = verses ?? QuranTextRepository.instance.versesForSurah;

  static final instance = TajweedRepository();
  static const _asset = 'assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json';

  final Future<String> Function() _loadAsset;
  final Future<List<String>> Function(int surah) _verses;
  Future<List<List<int>>>? _spans;
  List<TajweedRule?> _rules = const [];

  Future<List<List<int>>> _load() => _spans ??= () async {
    final root = jsonDecode(await _loadAsset()) as Map<String, dynamic>;
    _rules = [for (final name in root['rules'] as List) cpfairRules[name]];
    final verses = [
      for (final verse in root['verses'] as List) (verse as List).cast<int>(),
    ];
    if (verses.length != 6236) {
      throw StateError('Anotasi tajwid: ${verses.length} ayat, bukan 6236.');
    }
    return verses;
  }();

  static int _globalIndex(int surah, int ayah) {
    var index = 0;
    for (var s = 1; s < surah; s++) {
      index += surahCatalog[s - 1].ayahCount;
    }
    return index + ayah - 1;
  }

  /// Seluruh ayat [surah] dengan rentang tajwidnya.
  Future<List<TajweedVerse>> forSurah(int surah) async {
    final spans = await _load();
    final texts = await _verses(surah);
    final first = _globalIndex(surah, 1);
    return [
      for (var i = 0; i < texts.length; i++)
        _verse('$surah:${i + 1}', texts[i], spans[first + i]),
    ];
  }

  TajweedVerse _verse(String key, String text, List<int> flat) {
    final segments = <TajweedSegment>[];
    final rejected = <String>{};
    for (var i = 0; i + 2 < flat.length; i += 3) {
      final rule = _rules[flat[i]];
      final start = flat[i + 1];
      final end = flat[i + 2];
      if (rule == null || start < 0 || end > text.length || start >= end) {
        rejected.add('$key#${flat[i]}');
        continue;
      }
      // Rentang lebih pendek dianggap lebih dalam, supaya hukum yang
      // bersarang (mis. huruf mati di dalam mad) tetap terlihat.
      segments.add(
        TajweedSegment(
          start: start,
          end: end,
          rule: rule,
          depth: 1000 - (end - start),
        ),
      );
    }
    return TajweedVerse(
      verseKey: key,
      text: text,
      endMarker: null,
      segments: segments,
      rejectedClasses: rejected,
    );
  }
}
