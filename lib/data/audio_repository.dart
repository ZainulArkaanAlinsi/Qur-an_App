import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quran_app_2025/data/source_fallback.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';

/// Sumber audio murottal (API-Qur'an-gratis.md, "Kombinasi untuk Qur'an
/// App"):
///
/// - per ayat: cdn.islamic.network (alquran.cloud) — utama, dipakai untuk
///   hafalan dan ulang ayat;
/// - per surah: MP3Quran — utama;
/// - cadangan keduanya: equran.id.
///
/// EveryAyah tidak dipakai (lisensinya tidak jelas).
class AudioRepository {
  AudioRepository({http.Client? client, this.timeout = _defaultTimeout})
    : _client = client ?? http.Client();

  static const _defaultTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Duration timeout;

  /// Folder qari equran.id (API v2, kunci "01"–"06").
  static const equranQari = {
    '01': 'Abdullah-Al-Juhany',
    '02': 'Abdul-Muhsin-Al-Qasim',
    '03': 'Abdurrahman-as-Sudais',
    '04': 'Ibrahim-Al-Dossari',
    '05': 'Misyari-Rasyid-Al-Afasi',
    '06': 'Yasser-Al-Dosari',
  };

  /// Qari yang sama di equran.id untuk identifier alquran.cloud.
  static const _equranSame = {
    'ar.alafasy': '05',
    'ar.abdurrahmaansudais': '03',
  };

  /// Qari yang sama di MP3Quran (id dari API v3, sudah diperiksa).
  static const _mp3QuranSame = {'ar.alafasy': 123};

  /// Qari equran.id untuk [reciter]: yang sama bila ada, kalau tidak
  /// Misyari Rasyid ("05") sebagai cadangan.
  static String equranQariFor(Reciter reciter) =>
      _equranSame[reciter.identifier] ?? '05';

  /// Apakah cadangan equran.id memakai qari yang sama dengan pilihan.
  static bool equranIsSameReciter(Reciter reciter) =>
      _equranSame.containsKey(reciter.identifier);

  static String _pad(int value) => value.toString().padLeft(3, '0');

  /// Utama per ayat: cdn.islamic.network.
  static Uri islamicNetworkAyah(Reciter reciter, int surah, int ayah) =>
      Uri.https(
        'cdn.islamic.network',
        '/quran/audio/${reciter.bitrate ?? 128}/${reciter.identifier}/'
            '${globalAyahNumber(surah, ayah)}.mp3',
      );

  /// Cadangan per ayat: equran.id.
  static Uri equranAyah(String qari, int surah, int ayah) => Uri.https(
    'cdn.equran.id',
    '/audio-partial/${equranQari[qari]}/${_pad(surah)}${_pad(ayah)}.mp3',
  );

  /// Cadangan per surah: equran.id.
  static Uri equranSurah(String qari, int surah) => Uri.https(
    'cdn.equran.id',
    '/audio-full/${equranQari[qari]}/${_pad(surah)}.mp3',
  );

  /// Utama per surah: MP3Quran. Hanya mushaf riwayat Hafs yang dipakai,
  /// karena teks aplikasi ini riwayat Hafs.
  Future<Uri> mp3QuranSurah(int reciterId, int surah) async {
    final response = await _client.get(
      Uri.https('www.mp3quran.net', '/api/v3/reciters', {
        'language': 'eng',
        'reciter': '$reciterId',
      }),
    );
    if (response.statusCode != 200) {
      throw http.ClientException('MP3Quran ${response.statusCode}');
    }
    final root = jsonDecode(utf8.decode(response.bodyBytes));
    final reciters = (root as Map<String, dynamic>)['reciters'] as List?;
    for (final reciter in reciters ?? const []) {
      for (final moshaf in (reciter as Map)['moshaf'] as List? ?? const []) {
        final entry = moshaf as Map;
        final hafs = entry['rewaya_id'] == 1;
        final surahs = '${entry['surah_list']}'.split(',');
        final server = entry['server'] as String?;
        if (hafs && server != null && surahs.contains('$surah')) {
          return Uri.parse('$server${_pad(surah)}.mp3');
        }
      }
    }
    throw StateError('MP3Quran tidak punya surah $surah riwayat Hafs.');
  }

  /// Memastikan berkas cadangan benar-benar ada sebelum diputar.
  Future<Uri> _reachable(Uri uri) async {
    final response = await _client.head(uri);
    if (response.statusCode >= 400) {
      throw http.ClientException('${response.statusCode}', uri);
    }
    return uri;
  }

  /// Audio satu surah penuh: MP3Quran bila qarinya ada di sana, lalu
  /// equran.id. [SourceResult.fromFallback] menandai sumber cadangan.
  Future<SourceResult<Uri>> surahAudio(Reciter reciter, int surah) {
    final mp3Id = _mp3QuranSame[reciter.identifier];
    return firstAvailable<Uri>([
      if (mp3Id != null) () => mp3QuranSurah(mp3Id, surah),
      () => _reachable(equranSurah(equranQariFor(reciter), surah)),
    ], timeout: timeout);
  }
}
