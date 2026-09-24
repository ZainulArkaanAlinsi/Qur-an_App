import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/data/source_fallback.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Penyedia terjemahan yang bisa diunduh (API-Qur'an-gratis.md).
enum TranslationProvider {
  quranEnc(
    'QuranEnc',
    'https://quranenc.com',
    'Tanpa kunci API; teks tidak boleh diubah; sebut sumber dan versi.',
  ),
  fawazahmed0(
    'fawazahmed0/quran-api',
    'https://github.com/fawazahmed0/quran-api',
    'Repositori Unlicense; hak cipta tiap terjemahan tetap milik '
        'penerjemahnya.',
  );

  const TranslationProvider(this.label, this.url, this.license);
  final String label;
  final String url;
  final String license;
}

/// Satu terjemahan yang bisa diunduh.
@immutable
class TranslationEdition {
  const TranslationEdition({
    required this.provider,
    required this.id,
    required this.title,
    required this.language,
    this.version,
    this.direction = 'ltr',
  });

  factory TranslationEdition.fromJson(Map<String, dynamic> json) =>
      TranslationEdition(
        provider: TranslationProvider.values.byName(json['provider'] as String),
        id: json['id'] as String,
        title: json['title'] as String,
        language: json['language'] as String,
        version: json['version'] as String?,
        direction: json['direction'] as String? ?? 'ltr',
      );

  final TranslationProvider provider;

  /// Kunci QuranEnc (`english_saheeh`) atau nama edisi fawazahmed0
  /// (`eng-ummmuhammad`).
  final String id;

  /// Judul dari sumbernya, apa adanya (memuat nama penerjemah).
  final String title;

  /// Kode ISO (QuranEnc) atau nama bahasa (fawazahmed0).
  final String language;

  /// Versi dari sumber, bila ada (QuranEnc).
  final String? version;
  final String direction;

  String get cacheKey => '${provider.name}__$id';

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'id': id,
    'title': title,
    'language': language,
    'version': version,
    'direction': direction,
  };

  @override
  bool operator ==(Object other) =>
      other is TranslationEdition &&
      other.provider == provider &&
      other.id == id;

  @override
  int get hashCode => Object.hash(provider, id);
}

/// Terjemahan yang tersimpan di perangkat.
@immutable
class SavedTranslation {
  const SavedTranslation(this.edition, this.verses, this.savedAt);

  final TranslationEdition edition;

  /// Per surah, per ayat, persis seperti dari sumbernya.
  final List<List<String>> verses;
  final DateTime savedAt;
}

/// Katalog dan unduhan terjemahan: QuranEnc (utama), fawazahmed0 (cadangan).
/// Diunduh sekali, disimpan di perangkat, lalu dibaca tanpa internet.
///
/// Teks terjemahan TIDAK diubah: tanpa trim, replace, atau normalisasi.
class OnlineTranslations {
  OnlineTranslations({
    http.Client? client,
    Future<Directory> Function()? directory,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _directory = directory ?? getApplicationDocumentsDirectory;

  final http.Client _client;
  final Future<Directory> Function() _directory;
  final Duration timeout;

  /// Naik setiap kali ada terjemahan yang disimpan atau dihapus.
  final revision = ValueNotifier<int>(0);

  /// Padanan terjemahan yang sama di fawazahmed0 untuk kunci QuranEnc,
  /// dipakai bila unduhan QuranEnc gagal. Hanya yang penerjemahnya sama.
  static const fallbackOf = {'english_saheeh': 'eng-ummmuhammad'};

  static const _expectedVerses = 6236;

  Future<Directory> _folder() async {
    final base = await _directory();
    final folder = Directory('${base.path}/terjemahan');
    await folder.create(recursive: true);
    return folder;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------- katalog

  Future<List<TranslationEdition>> _quranEncCatalog() async {
    final root = await _getJson(
      Uri.https('quranenc.com', '/api/v1/translations/list'),
    );
    return [
      for (final item in root['translations'] as List)
        TranslationEdition(
          provider: TranslationProvider.quranEnc,
          id: (item as Map)['key'] as String,
          title: item['title'] as String,
          language: item['language_iso_code'] as String,
          version: item['version'] as String?,
          direction: item['direction'] as String? ?? 'ltr',
        ),
    ];
  }

  Future<List<TranslationEdition>> _fawazCatalog() async {
    final root = await _getJson(
      Uri.https(
        'cdn.jsdelivr.net',
        '/gh/fawazahmed0/quran-api@1/editions.json',
      ),
    );
    return [
      for (final entry in root.values.cast<Map>())
        if (entry['language'] != 'Arabic')
          TranslationEdition(
            provider: TranslationProvider.fawazahmed0,
            id: entry['name'] as String,
            title: entry['author'] as String,
            language: entry['language'] as String,
            direction: entry['direction'] as String? ?? 'ltr',
          ),
    ];
  }

  /// Daftar terjemahan: QuranEnc, lalu fawazahmed0 bila QuranEnc gagal.
  /// Daftar terakhir yang berhasil disimpan; saat luring daftar itu yang
  /// dipakai. Melempar [SourceUnavailable] bila tidak ada sama sekali.
  Future<SourceResult<List<TranslationEdition>>> catalog() async {
    final cache = File('${(await _folder()).path}/katalog.json');
    try {
      final result = await firstAvailable([
        _quranEncCatalog,
        _fawazCatalog,
      ], timeout: timeout);
      await _writeAtomic(
        cache,
        jsonEncode({
          'fallback': result.fromFallback,
          'editions': [for (final e in result.value) e.toJson()],
        }),
      );
      return result;
    } on SourceUnavailable {
      if (await cache.exists()) {
        final root = jsonDecode(await cache.readAsString()) as Map;
        return SourceResult([
          for (final e in root['editions'] as List)
            TranslationEdition.fromJson(e as Map<String, dynamic>),
        ], root['fallback'] == true ? 1 : 0);
      }
      rethrow;
    }
  }

  // ----------------------------------------------------------------- unduh

  Future<List<List<String>>> _quranEncVerses(String key) async {
    final surahs = <List<String>>[];
    for (final meta in surahCatalog) {
      final root = await _getJson(
        Uri.https(
          'quranenc.com',
          '/api/v1/translation/sura/$key/${meta.number}',
        ),
      );
      final verses = List<String?>.filled(meta.ayahCount, null);
      for (final row in (root['result'] as List).cast<Map>()) {
        final ayah = int.parse('${row['aya']}');
        // Verbatim: tanpa trim/replace.
        verses[ayah - 1] = row['translation'] as String;
      }
      surahs.add(_complete(verses, meta.number));
    }
    return surahs;
  }

  Future<List<List<String>>> _fawazVerses(String edition) async {
    final root = await _getJson(
      Uri.https(
        'cdn.jsdelivr.net',
        '/gh/fawazahmed0/quran-api@1/editions/$edition.min.json',
      ),
    );
    final bySurah = [
      for (final meta in surahCatalog)
        List<String?>.filled(meta.ayahCount, null),
    ];
    for (final row in (root['quran'] as List).cast<Map>()) {
      final surah = row['chapter'] as int;
      final ayah = row['verse'] as int;
      // Verbatim: tanpa trim/replace.
      bySurah[surah - 1][ayah - 1] = row['text'] as String;
    }
    return [
      for (var i = 0; i < bySurah.length; i++) _complete(bySurah[i], i + 1),
    ];
  }

  /// Menolak data yang tidak lengkap, supaya tidak ada terjemahan setengah
  /// jadi yang tersimpan.
  static List<String> _complete(List<String?> verses, int surah) {
    final missing = verses.indexWhere((v) => v == null);
    if (missing >= 0) {
      throw FormatException('Terjemahan $surah:${missing + 1} tidak ada.');
    }
    return List<String>.unmodifiable(verses.cast<String>());
  }

  Future<List<List<String>>> _versesOf(TranslationEdition edition) =>
      switch (edition.provider) {
        TranslationProvider.quranEnc => _quranEncVerses(edition.id),
        TranslationProvider.fawazahmed0 => _fawazVerses(edition.id),
      };

  /// Mengunduh dan menyimpan [edition]. Bila sumbernya gagal dan ada
  /// padanan terjemahan yang sama di fawazahmed0, padanan itu yang disimpan.
  /// Mengembalikan edisi yang benar-benar tersimpan.
  Future<TranslationEdition> download(TranslationEdition edition) async {
    final alternate = edition.provider == TranslationProvider.quranEnc
        ? fallbackOf[edition.id]
        : null;
    final candidates = [
      edition,
      if (alternate != null)
        TranslationEdition(
          provider: TranslationProvider.fawazahmed0,
          id: alternate,
          title: edition.title,
          language: edition.language,
          direction: edition.direction,
        ),
    ];
    final result = await firstAvailable([
      for (final candidate in candidates) () => _versesOf(candidate),
    ], timeout: timeout * 30);
    final saved = candidates[result.index];
    final count = result.value.fold<int>(0, (sum, s) => sum + s.length);
    if (count != _expectedVerses) {
      throw FormatException('Terjemahan tidak lengkap: $count ayat.');
    }
    final file = File('${(await _folder()).path}/${saved.cacheKey}.json');
    await _writeAtomic(
      file,
      jsonEncode({
        'edition': saved.toJson(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'verses': result.value,
      }),
    );
    revision.value++;
    return saved;
  }

  /// Tulis ke berkas sementara lalu ganti nama: cache tidak pernah terisi
  /// setengah jalan walau aplikasi tertutup di tengah.
  static Future<void> _writeAtomic(File file, String content) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(file.path);
  }

  // ----------------------------------------------------------------- cache

  /// Terjemahan yang sudah tersimpan, terbaca tanpa internet.
  Future<List<SavedTranslation>> saved() async {
    final folder = await _folder();
    final result = <SavedTranslation>[];
    await for (final entity in folder.list()) {
      if (entity is! File ||
          !entity.path.endsWith('.json') ||
          entity.path.endsWith('katalog.json')) {
        continue;
      }
      try {
        result.add(_read(await entity.readAsString()));
      } on Object {
        // Berkas rusak dilewati; tidak menjatuhkan daftar lainnya.
      }
    }
    return result;
  }

  static SavedTranslation _read(String raw) {
    final root = jsonDecode(raw) as Map<String, dynamic>;
    return SavedTranslation(
      TranslationEdition.fromJson(root['edition'] as Map<String, dynamic>),
      [
        for (final surah in root['verses'] as List)
          List<String>.unmodifiable((surah as List).cast<String>()),
      ],
      DateTime.parse(root['savedAt'] as String),
    );
  }

  /// Satu terjemahan tersimpan, atau null bila belum diunduh.
  Future<SavedTranslation?> load(TranslationEdition edition) async {
    final file = File('${(await _folder()).path}/${edition.cacheKey}.json');
    if (!await file.exists()) return null;
    return _read(await file.readAsString());
  }

  Future<void> remove(TranslationEdition edition) async {
    final file = File('${(await _folder()).path}/${edition.cacheKey}.json');
    if (await file.exists()) await file.delete();
    revision.value++;
  }
}
