import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

/// Edisi layout mushaf yang dapat dipilih. Keduanya memakai data kata dan
/// glyph `code_v2` yang sama (Mushaf Madinah, QCF), hanya font halamannya
/// yang berbeda. Pengguna tidak dapat mengganti font mushaf secara bebas.
enum MushafEdition {
  standard('Mushaf Biasa', 'QCF V2', 'v2/ttf'),
  tajweed('Mushaf Tajwid', 'QCF V4 (COLRv1)', 'v4/colrv1/ttf');

  const MushafEdition(this.label, this.technicalName, this._fontPath);

  final String label;
  final String technicalName;
  final String _fontPath;

  String fontFamily(int page) => 'qcf_${name}_p$page';

  Uri fontUri(int page) => Uri.parse(
        'https://verses.quran.foundation/fonts/quran/hafs/$_fontPath/p$page.ttf',
      );
}

typedef FontRegistrar = Future<void> Function(String family, Uint8List bytes);

/// Sumber data KHUSUS build debug: memanggil endpoint publik api.quran.com
/// dan CDN font Quran Foundation langsung dari perangkat. Produksi wajib lewat
/// BFF + Content API resmi dan font yang di-cache sesuai ketentuan
/// (docs/DATA_SOURCES_AND_LICENSES.md).
class QfDebugMushafSource {
  QfDebugMushafSource({http.Client? client, FontRegistrar? registerFont})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _registerFont = registerFont ?? _loadFont;

  static const _api = 'https://api.quran.com/api/v4';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final bool _ownsClient;
  final FontRegistrar _registerFont;
  final _cache = <String, Future<Object?>>{};

  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// Hasil sukses di-cache; kegagalan dibuang agar "coba lagi" memuat ulang.
  Future<T> _memo<T>(String key, Future<T> Function() load) {
    final cached = _cache[key];
    if (cached != null) return cached.then((value) => value as T);
    final future = load();
    _cache[key] = future;
    future.then<void>((_) {}, onError: (Object _) {
      _cache.remove(key);
    });
    return future;
  }

  Future<Map> _getJson(String path) async {
    final uri = Uri.parse('$_api/$path');
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  }

  // `by_page` memilih ayat menurut halaman V1, sedangkan `page_number` dan
  // `line_number` tiap kata sudah mengikuti mushaf=1 (V2). Satu halaman V2
  // bisa tersebar di respons halaman tetangga, jadi ambil N-1..N+2 lalu saring.
  Future<List<MushafWord>> _wordsOfV1Page(int page) =>
      _memo('by_page:$page', () async {
        final json = await _getJson(
          'verses/by_page/$page?words=true&per_page=50&mushaf=1'
          '&word_fields=code_v2,line_number,page_number',
        );
        return [
          for (final verse in json['verses'] as List)
            for (final word in verse['words'] as List)
              _parseWord(verse['verse_key'] as String, word as Map),
        ];
      });

  static MushafWord _parseWord(String verseKey, Map word) {
    final key = verseKey.split(':');
    return MushafWord(
      id: word['id'] as int,
      page: word['page_number'] as int,
      line: word['line_number'] as int,
      surah: int.parse(key[0]),
      ayah: int.parse(key[1]),
      position: word['position'] as int,
      isVerseEnd: word['char_type_name'] == 'end',
      glyph: word['code_v2'] as String,
    );
  }

  Future<MushafPage> page(int number) => _memo('page:$number', () async {
        final sources = [
          for (var n = number - 1; n <= number + 2; n++)
            if (n >= 1 && n <= mushafPageCount) _wordsOfV1Page(n),
        ];
        final words = (await Future.wait(sources)).expand((w) => w);
        return buildMushafPage(number, words);
      });

  /// Memuat font halaman [page] untuk [edition]; mengembalikan nama family.
  Future<String> ensureFont(MushafEdition edition, int page) {
    final family = edition.fontFamily(page);
    return _memo('font:$family', () async {
      final uri = edition.fontUri(page);
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      await _registerFont(family, response.bodyBytes);
      return family;
    });
  }

  /// Nama surah berbahasa Arab dari metadata provider, untuk bingkai judul.
  Future<Map<int, String>> surahNames() => _memo('chapters', () async {
        final json = await _getJson('chapters');
        return {
          for (final chapter in json['chapters'] as List)
            chapter['id'] as int: chapter['name_arabic'] as String,
        };
      });

  Future<Map<String, String>> _verses(String field, int surah) =>
      _memo('$field:$surah', () async {
        final json = await _getJson(
          'quran/verses/$field?chapter_number=$surah',
        );
        return {
          for (final verse in json['verses'] as List)
            verse['verse_key'] as String: verse['text_$field'] as String,
        };
      });

  Future<Map<String, String>> tajweedMarkup(int surah) =>
      _verses('uthmani_tajweed', surah);

  Future<Map<String, String>> uthmani(int surah) => _verses('uthmani', surah);
}

Future<void> _loadFont(String family, Uint8List bytes) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
