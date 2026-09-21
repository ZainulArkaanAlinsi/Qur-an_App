import 'dart:convert';

import 'package:http/http.dart' as http;

class TranslationRepository {
  TranslationRepository._();
  static final instance = TranslationRepository._();
  final _cache = <int, List<String>>{};

  Future<List<String>> forSurah(int surah) async {
    final cached = _cache[surah];
    if (cached != null) return cached;
    final response = await http
        .get(Uri.https('api.alquran.cloud', '/v1/surah/$surah/id.indonesian'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw Exception('Terjemahan belum tersedia.');
    final data =
        (jsonDecode(response.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>?;
    final ayahs = data?['ayahs'] as List<dynamic>?;
    if (ayahs == null || ayahs.isEmpty)
      throw const FormatException('Respons terjemahan tidak lengkap.');
    final result = ayahs
        .map((ayah) => (ayah as Map<String, dynamic>)['text'] as String? ?? '')
        .toList(growable: false);
    _cache[surah] = result;
    return result;
  }
}
