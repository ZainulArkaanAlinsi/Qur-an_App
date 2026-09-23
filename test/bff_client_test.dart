import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/core/bff/bff_client.dart';
import 'package:quran_app_2025/features/mushaf/data/bff_mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/data/mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

const _base = 'https://bff.example.test';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

/// Satu halaman 15 baris dengan satu kata per baris.
List<Map<String, Object>> _pageWords(int page) => [
  for (var line = 1; line <= 15; line++)
    {
      'id': page * 100 + line,
      'page': page,
      'line': line,
      'verseKey': '2:$line',
      'position': line,
      'type': 'word',
      'glyph': 'g$line',
    },
];

/// Pengganti ringan untuk kegagalan jaringan.
class _NetworkFailure implements Exception {
  const _NetworkFailure();
}

void main() {
  group('BffClient', () {
    test('menolak bekerja saat BFF_BASE_URL kosong', () async {
      final client = BffClient(
        baseUrl: '',
        client: MockClient((_) async => fail('tidak boleh ada permintaan')),
      );
      await expectLater(
        client.getJson('v1/health'),
        throwsA(
          isA<BffException>().having(
            (error) => error.message,
            'message',
            contains('BFF_BASE_URL'),
          ),
        ),
      );
    });

    test('membangun URL dan membaca JSON UTF-8', () async {
      Uri? requested;
      final client = BffClient(
        baseUrl: _base,
        client: MockClient((request) async {
          requested = request.url;
          return _json({'nama': 'الفاتحة'});
        }),
      );
      final body = await client.getJson('v1/chapters', {'page': '1'});
      expect(requested.toString(), '$_base/v1/chapters?page=1');
      expect(body['nama'], 'الفاتحة');
    });

    test('status non-200 menjadi pesan yang bisa ditampilkan', () async {
      for (final (status, fragment) in [
        (429, 'Terlalu banyak'),
        (404, 'tidak ditemukan'),
        (500, '500'),
      ]) {
        final client = BffClient(
          baseUrl: _base,
          client: MockClient((_) async => _json({'error': 'x'}, status)),
        );
        await expectLater(
          client.getJson('v1/health'),
          throwsA(
            isA<BffException>()
                .having((error) => error.statusCode, 'statusCode', status)
                .having(
                  (error) => error.message,
                  'message',
                  contains(fragment),
                ),
          ),
        );
      }
    });

    test('kegagalan jaringan dibungkus BffException', () async {
      final client = BffClient(
        baseUrl: _base,
        client: MockClient((_) async => throw const _NetworkFailure()),
      );
      await expectLater(
        client.getJson('v1/health'),
        throwsA(isA<BffException>()),
      );
    });
  });

  group('BffMushafSource', () {
    BffMushafSource source(MockClient client) => BffMushafSource(
      client: BffClient(baseUrl: _base, client: client),
      fontClient: client,
      registerFont: (_, _) async {},
    );

    test('halaman dipetakan ke model dan disusun per baris', () async {
      final instance = source(
        MockClient((request) async {
          expect(request.url.path, '/v1/mushaf/v2/pages/3');
          return _json({
            'page': 3,
            'edition': 'qcf-v2',
            'words': _pageWords(3),
          });
        }),
      );
      addTearDown(instance.dispose);

      final page = await instance.page(3);
      expect(page.number, 3);
      expect(page.lines, hasLength(15));
      expect(page.lines.whereType<MushafTextLine>(), hasLength(15));
      expect(page.verseKeys.first, '2:1');
    });

    test(
      'halaman dengan baris hilang tetap ditolak di sisi aplikasi',
      () async {
        final instance = source(
          MockClient((_) async {
            final words = _pageWords(3)
              ..removeWhere((word) => word['line'] == 7);
            return _json({'page': 3, 'words': words});
          }),
        );
        addTearDown(instance.dispose);

        await expectLater(
          instance.page(3),
          throwsA(isA<MushafLayoutException>()),
        );
      },
    );

    test('halaman yang sama hanya diminta sekali', () async {
      var calls = 0;
      final instance = source(
        MockClient((_) async {
          calls++;
          return _json({'page': 3, 'words': _pageWords(3)});
        }),
      );
      addTearDown(instance.dispose);

      await instance.page(3);
      await instance.page(3);
      expect(calls, 1);
    });

    test('kegagalan tidak disimpan di cache', () async {
      var calls = 0;
      final instance = source(
        MockClient((_) async {
          calls++;
          return calls == 1
              ? _json({'error': 'x'}, 500)
              : _json({'page': 3, 'words': _pageWords(3)});
        }),
      );
      addTearDown(instance.dispose);

      await expectLater(instance.page(3), throwsA(isA<BffException>()));
      await instance.page(3);
      expect(calls, 2);
    });

    test('nama surah dan markup tajwid dipetakan per verseKey', () async {
      final instance = source(
        MockClient((request) async {
          if (request.url.path == '/v1/chapters') {
            return _json({
              'chapters': [
                {'id': 1, 'nameArabic': 'الفاتحة'},
              ],
            });
          }
          return _json({
            'chapter': 1,
            'verses': [
              {'verseKey': '1:1', 'markup': '<span class=end>١</span>'},
            ],
          });
        }),
      );
      addTearDown(instance.dispose);

      expect(await instance.surahNames(), {1: 'الفاتحة'});
      expect(await instance.tajweedMarkup(1), {
        '1:1': '<span class=end>١</span>',
      });
    });

    test('font halaman diambil dari CDN Quran Foundation', () async {
      Uri? fontUri;
      final instance = source(
        MockClient((request) async {
          fontUri = request.url;
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      addTearDown(instance.dispose);

      final family = await instance.ensureFont(MushafEdition.tajweed, 50);
      expect(family, 'qcf_tajweed_p50');
      expect(
        fontUri.toString(),
        'https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/ttf/p50.ttf',
      );
    });
  });
}
