import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/core/bff/bff_client.dart';
import 'package:quran_app_2025/features/mushaf/data/mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

typedef FontRegistrar = Future<void> Function(String family, Uint8List bytes);

/// Sumber mushaf lewat BFF sendiri. Aplikasi tidak pernah memegang kredensial
/// Quran Foundation; penyaringan halaman dan bentuk data sudah diselesaikan
/// server, jadi di sini tinggal memetakan JSON ke model.
class BffMushafSource implements MushafSource {
  BffMushafSource({
    BffClient? client,
    http.Client? fontClient,
    FontRegistrar? registerFont,
  }) : _client = client ?? BffClient(),
       _fontClient = fontClient ?? http.Client(),
       _ownsFontClient = fontClient == null,
       _registerFont = registerFont ?? _loadFont;

  final BffClient _client;
  final http.Client _fontClient;
  final bool _ownsFontClient;
  final FontRegistrar _registerFont;
  final _cache = <String, Future<Object?>>{};

  @override
  void dispose() {
    _client.dispose();
    if (_ownsFontClient) _fontClient.close();
  }

  /// Hasil sukses di-cache; kegagalan dibuang agar percobaan ulang benar-benar
  /// memuat ulang.
  Future<T> _memo<T>(String key, Future<T> Function() load) {
    final cached = _cache[key];
    if (cached != null) return cached.then((value) => value as T);
    final future = load();
    _cache[key] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        _cache.remove(key);
      },
    );
    return future;
  }

  @override
  Future<MushafPage> page(int number) => _memo('page:$number', () async {
    final json = await _client.getJson('v1/mushaf/v2/pages/$number');
    final words = [
      for (final raw in json['words'] as List)
        _word(raw as Map<String, dynamic>),
    ];
    // Susunan baris tetap divalidasi di sisi aplikasi: halaman dengan data
    // tidak konsisten ditolak, bukan ditampilkan sebagai tebakan.
    return buildMushafPage(number, words);
  });

  static MushafWord _word(Map<String, dynamic> raw) {
    final key = (raw['verseKey'] as String).split(':');
    return MushafWord(
      id: raw['id'] as int,
      page: raw['page'] as int,
      line: raw['line'] as int,
      surah: int.parse(key[0]),
      ayah: int.parse(key[1]),
      position: raw['position'] as int,
      isVerseEnd: raw['type'] == 'end',
      glyph: raw['glyph'] as String,
    );
  }

  @override
  Future<Map<int, String>> surahNames() => _memo('chapters', () async {
    final json = await _client.getJson('v1/chapters');
    return {
      for (final chapter in json['chapters'] as List)
        (chapter as Map<String, dynamic>)['id'] as int:
            chapter['nameArabic'] as String,
    };
  });

  @override
  Future<Map<String, String>> tajweedMarkup(int surah) =>
      _memo('tajweed:$surah', () async {
        final json = await _client.getJson('v1/chapters/$surah/tajweed');
        return {
          for (final verse in json['verses'] as List)
            (verse as Map<String, dynamic>)['verseKey'] as String:
                verse['markup'] as String,
        };
      });

  /// Teks polos edisi cadangan. Endpoint ini **belum ada** di `bff/` (baru
  /// tajwid yang tersedia), jadi pemanggilnya akan menerima 404 sampai
  /// endpoint ditambahkan.
  @override
  Future<Map<String, String>> uthmani(int surah) =>
      _memo('uthmani:$surah', () async {
        final json = await _client.getJson('v1/chapters/$surah/uthmani');
        return {
          for (final verse in json['verses'] as List)
            (verse as Map<String, dynamic>)['verseKey'] as String:
                verse['text'] as String,
        };
      });

  @override
  Future<String> ensureFont(MushafEdition edition, int page) {
    final family = edition.fontFamily(page);
    return _memo('font:$family', () async {
      final uri = edition.fontUri(page);
      final response = await _fontClient.get(uri).timeout(_client.timeout);
      if (response.statusCode != 200) {
        throw BffException(
          'Font halaman $page gagal dimuat.',
          statusCode: response.statusCode,
        );
      }
      await _registerFont(family, response.bodyBytes);
      return family;
    });
  }
}

Future<void> _loadFont(String family, Uint8List bytes) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
