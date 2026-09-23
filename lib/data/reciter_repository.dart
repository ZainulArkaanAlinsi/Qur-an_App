import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daftar qari murottal per ayat dari Al Quran Cloud (tanpa API key).
///
/// Daftarnya diambil dari endpoint resources, bukan ditulis tetap di kode,
/// supaya qari yang ditambah atau dicabut providernya ikut terbawa. Hasilnya
/// di-cache seminggu agar aplikasi tetap dapat memilih qari saat offline.
class ReciterRepository {
  ReciterRepository({http.Client? client}) : _client = client;

  static const _listUrl =
      'https://api.alquran.cloud/v1/edition?format=audio&type=versebyverse';
  static const _cacheKey = 'reciters_cache';
  static const _cacheAtKey = 'reciters_cached_at';
  static const cacheDuration = Duration(days: 7);

  /// Urutan preferensi kualitas; CDN hanya menyediakan sebagian per qari.
  static const bitrateCandidates = [128, 64, 192];

  /// Urutan saat mode hemat kuota aktif: berkas terkecil lebih dulu.
  static const lowDataBitrateCandidates = [64, 128, 192];

  final http.Client? _client;

  Future<T> _withClient<T>(Future<T> Function(http.Client) run) async {
    final client = _client ?? http.Client();
    try {
      return await run(client);
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Daftar qari: dari cache bila masih segar, kalau tidak dari jaringan.
  /// Gagal jaringan mengembalikan cache lama, atau daftar bawaan.
  Future<List<Reciter>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt(_cacheAtKey);
    final cached = prefs.getString(_cacheKey);
    final fresh =
        cachedAt != null &&
        DateTime.now().millisecondsSinceEpoch - cachedAt <
            cacheDuration.inMilliseconds;
    if (!forceRefresh && fresh && cached != null) {
      final list = _decode(cached);
      if (list.isNotEmpty) return list;
    }

    try {
      final reciters = await _withClient((client) async {
        final response = await client
            .get(Uri.parse(_listUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw http.ClientException('HTTP ${response.statusCode}');
        }
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return [
          for (final edition in body['data'] as List)
            Reciter.fromEdition(edition as Map<String, dynamic>),
        ];
      });
      if (reciters.isEmpty) throw const FormatException('Daftar qari kosong');
      await prefs.setString(
        _cacheKey,
        jsonEncode([for (final reciter in reciters) reciter.toJson()]),
      );
      await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
      return reciters;
    } on Object catch (error) {
      debugPrint('Daftar qari gagal dimuat: $error');
      if (cached != null) {
        final list = _decode(cached);
        if (list.isNotEmpty) return list;
      }
      return const [defaultReciter];
    }
  }

  List<Reciter> _decode(String raw) {
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          Reciter.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      return const [];
    }
  }

  /// Mencari bitrate yang benar-benar tersedia untuk [reciter]. Mengembalikan
  /// `null` bila tidak ada satu pun yang dapat diputar, sehingga pemanggil
  /// tidak menyimpan pilihan yang pasti gagal.
  Future<Reciter?> resolveBitrate(Reciter reciter, {bool? lowData}) async {
    final saveData = lowData ?? SharedPreferencesService.getLowDataAudio();
    final candidates = saveData
        ? lowDataBitrateCandidates
        : bitrateCandidates;
    return _withClient((client) async {
      for (final bitrate in candidates) {
        final uri = Uri.https(
          'cdn.islamic.network',
          '/quran/audio/$bitrate/${reciter.identifier}/1.mp3',
        );
        try {
          final response = await client
              .head(uri)
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) return reciter.withBitrate(bitrate);
        } on Object catch (error) {
          debugPrint('Cek bitrate $bitrate gagal: $error');
        }
      }
      return null;
    });
  }
}
