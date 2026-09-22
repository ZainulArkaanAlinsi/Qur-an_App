import 'dart:convert';

import 'package:http/http.dart' as http;

/// Alamat BFF milik sendiri, diisi saat build:
/// `flutter build apk --dart-define=BFF_BASE_URL=https://...`.
///
/// Kosong berarti BFF belum dikonfigurasi; aplikasi harus tetap jalan dengan
/// data offline yang sudah dibundel dan tidak boleh menebak alamat lain.
const bffBaseUrl = String.fromEnvironment('BFF_BASE_URL');

bool get isBffConfigured => bffBaseUrl.isNotEmpty;

class BffException implements Exception {
  const BffException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BffException($statusCode): $message';
}

/// Klien HTTP untuk BFF. Tidak pernah membawa kredensial provider: BFF yang
/// memegang `client_id`/`client_secret` (lihat bff/README.md).
class BffClient {
  BffClient({http.Client? client, String? baseUrl, this.timeout = _timeout})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? bffBaseUrl;

  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;
  final Duration timeout;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    if (_baseUrl.isEmpty) {
      throw const BffException('BFF belum dikonfigurasi (BFF_BASE_URL kosong)');
    }
    final uri = Uri.parse(
      '$_baseUrl/$path',
    ).replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } catch (error) {
      throw BffException('Tidak dapat menghubungi server: $error');
    }
    if (response.statusCode != 200) {
      throw BffException(switch (response.statusCode) {
        429 => 'Terlalu banyak permintaan, coba lagi nanti.',
        404 => 'Data tidak ditemukan di server.',
        _ => 'Server menjawab ${response.statusCode}.',
      }, statusCode: response.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw const BffException('Respons server tidak dapat dibaca.');
    }
  }
}
