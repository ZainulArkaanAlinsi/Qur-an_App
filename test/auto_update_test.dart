import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';

/// Pemasang tiruan: mencatat panggilan tanpa menyentuh platform Android.
class _FakeInstaller implements ApkInstaller {
  _FakeInstaller({this.allowed = true});

  final bool allowed;
  final installed = <String>[];
  var permissionRequests = 0;

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> install(String path) async => installed.add(path);

  @override
  Future<void> openPermissionSettings() async => permissionRequests++;
}

final _releasePage = Uri.parse('https://example.test/rilis');

AvailableUpdate _update({int? size}) => AvailableUpdate(
  version: '9.9.9',
  url: _releasePage,
  apkUrl: Uri.parse('https://example.test/app.apk'),
  apkSize: size,
);

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('auto_update_test');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  AutoUpdateService service({
    required http.Client client,
    required ApkInstaller installer,
    AvailableUpdate? update,
    bool isSupported = true,
  }) => AutoUpdateService(
    client: client,
    installer: installer,
    isSupported: isSupported,
    downloadDirectory: () async => directory,
    checkForUpdate: () async => update,
  );

  test('mengunduh APK lalu membuka pemasang tanpa langkah lain', () async {
    final installer = _FakeInstaller();
    final bytes = List<int>.filled(1024, 7);
    final result = await service(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      installer: installer,
      update: _update(size: bytes.length),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.installerOpened);
    expect(installer.installed.single, endsWith('ruang-tilawah-9.9.9.apk'));
    expect(File(installer.installed.single).lengthSync(), bytes.length);
  });

  test(
    'tanpa izin pasang, berkas tetap siap dan pemasang tidak dibuka',
    () async {
      final installer = _FakeInstaller(allowed: false);
      final result = await service(
        client: MockClient(
          (_) async => http.Response.bytes(List<int>.filled(10, 1), 200),
        ),
        installer: installer,
        update: _update(size: 10),
      ).run(enabled: true);

      expect(result, AutoUpdateOutcome.needsInstallPermission);
      expect(installer.installed, isEmpty);
    },
  );

  test('unduhan dengan ukuran tidak cocok tidak dipasang', () async {
    final installer = _FakeInstaller();
    final result = await service(
      client: MockClient(
        (_) async => http.Response.bytes(List<int>.filled(5, 1), 200),
      ),
      installer: installer,
      update: _update(size: 999),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.failed);
    expect(installer.installed, isEmpty);
  });

  test('berkas yang sudah lengkap tidak diunduh ulang', () async {
    final installer = _FakeInstaller();
    File(
      '${directory.path}/ruang-tilawah-9.9.9.apk',
    ).writeAsBytesSync(List<int>.filled(20, 3));
    var requests = 0;
    final result = await service(
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(List<int>.filled(20, 3), 200);
      }),
      installer: installer,
      update: _update(size: 20),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.installerOpened);
    expect(requests, 0);
  });

  test('berkas lama dengan ukuran salah diunduh ulang', () async {
    final installer = _FakeInstaller();
    File(
      '${directory.path}/ruang-tilawah-9.9.9.apk',
    ).writeAsBytesSync(List<int>.filled(3, 0));
    final result = await service(
      client: MockClient(
        (_) async => http.Response.bytes(List<int>.filled(20, 3), 200),
      ),
      installer: installer,
      update: _update(size: 20),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.installerOpened);
    expect(File(installer.installed.single).lengthSync(), 20);
  });

  test(
    'setelan mati atau platform tidak didukung: tidak ada jaringan',
    () async {
      final installer = _FakeInstaller();
      final client = MockClient(
        (_) async => fail('tidak boleh ada permintaan jaringan'),
      );
      expect(
        await service(
          client: client,
          installer: installer,
          update: _update(size: 1),
        ).run(enabled: false),
        AutoUpdateOutcome.nothingToDo,
      );
      expect(
        await service(
          client: client,
          installer: installer,
          update: _update(size: 1),
          isSupported: false,
        ).run(enabled: true),
        AutoUpdateOutcome.nothingToDo,
      );
    },
  );

  test('rilis tanpa berkas APK tidak memicu unduhan', () async {
    final result = await service(
      client: MockClient((_) async => fail('tidak boleh mengunduh')),
      installer: _FakeInstaller(),
      update: AvailableUpdate(version: '9.9.9', url: _releasePage),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.nothingToDo);
  });

  test('kegagalan jaringan dilaporkan, bukan dilempar', () async {
    final result = await service(
      client: MockClient((_) async => throw const SocketException('offline')),
      installer: _FakeInstaller(),
      update: _update(size: 10),
    ).run(enabled: true);

    expect(result, AutoUpdateOutcome.failed);
  });

  group('UpdateCheckService', () {
    http.Client releaseClient(Object body) =>
        MockClient((_) async => http.Response(jsonEncode(body), 200));

    test('mengambil tautan dan ukuran APK dari aset rilis', () async {
      final update = await UpdateCheckService.check(
        client: releaseClient({
          'tag_name': 'v99.0.0',
          'html_url': 'https://example.test/rilis',
          'assets': [
            {'name': 'catatan.txt', 'browser_download_url': 'x', 'size': 1},
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.test/app.apk',
              'size': 12345,
            },
          ],
        }),
      );

      expect(update!.version, '99.0.0');
      expect(update.apkUrl.toString(), 'https://example.test/app.apk');
      expect(update.apkSize, 12345);
    });

    test('rilis tanpa aset APK tetap dikenali sebagai pembaruan', () async {
      final update = await UpdateCheckService.check(
        client: releaseClient({
          'tag_name': 'v99.0.0',
          'html_url': 'https://example.test/rilis',
          'assets': <Object>[],
        }),
      );

      expect(update!.apkUrl, isNull);
      expect(update.apkSize, isNull);
    });

    test('versi yang sama dengan terpasang bukan pembaruan', () async {
      final update = await UpdateCheckService.check(
        client: releaseClient({
          'tag_name': 'v$appVersion',
          'html_url': 'https://example.test/rilis',
        }),
      );

      expect(update, isNull);
    });
  });
}
