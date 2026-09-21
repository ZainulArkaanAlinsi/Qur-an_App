import 'dart:convert';

import 'package:http/http.dart' as http;

class IslamicNewsArticle {
  const IslamicNewsArticle({
    required this.title,
    required this.source,
    required this.url,
    this.description,
  });
  final String title;
  final String source;
  final String url;
  final String? description;
}

class IslamicNewsService {
  /// Optional HTTPS backend for a curated provider such as GNews.
  static const _endpoint = String.fromEnvironment('ISLAMIC_NEWS_API_URL');

  static final _freeEndpoint = Uri.https(
    'api.gdeltproject.org',
    '/api/v2/doc/doc',
    {
      'query': '(Islam OR Muslim OR Ramadhan OR masjid) sourcelang:indonesian',
      'mode': 'artlist',
      'maxrecords': '20',
      'format': 'json',
      'sort': 'datedesc',
    },
  );

  static Future<List<IslamicNewsArticle>> fetchLatest() async {
    final uri = _endpoint.isEmpty ? _freeEndpoint : Uri.parse(_endpoint);
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Berita belum dapat dimuat (${response.statusCode}).');
    }
    final articles =
        (jsonDecode(response.body) as Map<String, dynamic>)['articles']
            as List<dynamic>? ??
        const [];
    return articles
        .map((raw) {
          final article = raw as Map<String, dynamic>;
          final source = article['source'] as Map<String, dynamic>?;
          return IslamicNewsArticle(
            title: article['title'] as String? ?? 'Berita Islam',
            source:
                source?['name'] as String? ??
                article['domain'] as String? ??
                'Sumber berita',
            url: article['url'] as String? ?? '',
            description: article['description'] as String?,
          );
        })
        .where((article) => article.url.isNotEmpty)
        .toList(growable: false);
  }
}
