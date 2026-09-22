import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/services/update_check_service.dart';

MockClient _release(String tag, {int status = 200}) => MockClient(
  (request) async => http.Response(
    jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/example/releases/tag/$tag',
    }),
    status,
  ),
);

void main() {
  group('compareVersions', () {
    test('membandingkan angka, bukan teks', () {
      expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
      expect(compareVersions('1.1.0', '1.1.0'), 0);
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('1.0.9', '1.1.0'), lessThan(0));
    });

    test('mengabaikan build number dan label pra-rilis', () {
      expect(compareVersions('1.2.0+7', '1.2.0'), 0);
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
    });
  });

  test('rilis lebih baru dilaporkan beserta tautannya', () async {
    final update = await UpdateCheckService.check(client: _release('v9.0.0'));
    expect(update?.version, '9.0.0');
    expect(update?.url.path, endsWith('/v9.0.0'));
  });

  test('versi yang sama atau lebih lama tidak dilaporkan', () async {
    expect(
      await UpdateCheckService.check(client: _release('v$appVersion')),
      isNull,
    );
    expect(await UpdateCheckService.check(client: _release('v0.1.0')), isNull);
  });

  test('respons gagal atau rusak tidak menimbulkan error', () async {
    expect(
      await UpdateCheckService.check(client: _release('v9.0.0', status: 404)),
      isNull,
    );
    final broken = MockClient((_) async => http.Response('bukan json', 200));
    expect(await UpdateCheckService.check(client: broken), isNull);
    final offline = MockClient((_) async => throw Exception('offline'));
    expect(await UpdateCheckService.check(client: offline), isNull);
  });
}
