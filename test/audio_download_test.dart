import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/widgets/surah_download_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al-Ikhlas (112) hanya 4 ayat, jadi cepat diuji.
const _surah = 112;
const _reciter = defaultReciter;

void main() {
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    directory = Directory.systemTemp.createTempSync('murottal_test');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  AudioDownloadService service(MockClient client) =>
      AudioDownloadService(client: client, directory: () async => directory);

  /// `content-length` disertakan agar perkiraan ukuran (HEAD) ikut teruji.
  MockClient okClient({List<int>? bytes, int status = 200}) {
    final body = bytes ?? [1, 2, 3];
    return MockClient(
      (_) async => http.Response.bytes(
        body,
        status,
        headers: {'content-length': '${body.length}'},
      ),
    );
  }

  test('mengunduh setiap ayat lalu surah ditandai lengkap', () async {
    final requested = <String>[];
    final downloader = service(
      MockClient((request) async {
        requested.add(request.url.path);
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );

    final progress = <int>[];
    final ok = await downloader.download(
      _reciter,
      _surah,
      onProgress: (value) => progress.add(value.done),
    );

    expect(ok, DownloadOutcome.completed);
    expect(progress, [1, 2, 3, 4]);
    expect(requested, hasLength(surahCatalog[_surah - 1].ayahCount));
    expect(requested.first, contains('/128/ar.alafasy/'));
    expect(await downloader.isComplete(_reciter, _surah), isTrue);
    expect(await downloader.storageUsed(_reciter), 12);
  });

  test(
    'ayat yang gagal menghentikan unduhan dan surah tidak dianggap lengkap',
    () async {
      var calls = 0;
      final downloader = service(
        MockClient((_) async {
          calls++;
          return http.Response.bytes([1], calls >= 3 ? 403 : 200);
        }),
      );

      expect(
        await downloader.download(_reciter, _surah),
        DownloadOutcome.failed,
      );
      expect(await downloader.isComplete(_reciter, _surah), isFalse);
      // Berhenti pada kegagalan, bukan melanjutkan sisa ayat.
      expect(calls, 3);
    },
  );

  test('ayat yang sudah ada tidak diunduh ulang', () async {
    final first = service(okClient());
    await first.download(_reciter, _surah);

    var calls = 0;
    final second = service(
      MockClient((_) async {
        calls++;
        return http.Response.bytes([9], 200);
      }),
    );
    expect(await second.download(_reciter, _surah), DownloadOutcome.completed);
    expect(calls, 0);
  });

  test('berkas kosong dianggap belum ada', () async {
    final downloader = service(okClient(bytes: []));
    expect(await downloader.download(_reciter, _surah), DownloadOutcome.failed);
    expect(await downloader.isComplete(_reciter, _surah), isFalse);
  });

  test('hapus surah dan hapus semua membersihkan penyimpanan', () async {
    final downloader = service(okClient());
    await downloader.download(_reciter, _surah);
    expect(await downloader.storageUsed(_reciter), greaterThan(0));

    await downloader.delete(_reciter, _surah);
    expect(await downloader.isComplete(_reciter, _surah), isFalse);
    expect(await downloader.storageUsed(_reciter), 0);

    await downloader.download(_reciter, _surah);
    await downloader.deleteAll(_reciter);
    expect(await downloader.storageUsed(_reciter), 0);
  });

  test(
    'pemutar memakai berkas lokal bila ada, selain itu tetap streaming',
    () async {
      final downloader = service(okClient());
      await downloader.download(_reciter, _surah);
      final folder = await downloader.folderPath(_reciter);
      expect(folder, isNotNull);

      final local = QuranAudioService.sourceFor(
        _surah,
        1,
        reciter: _reciter,
        folder: folder,
      );
      expect(local.scheme, 'file');

      // Surah yang belum diunduh tetap memakai CDN.
      final remote = QuranAudioService.sourceFor(
        2,
        255,
        reciter: _reciter,
        folder: folder,
      );
      expect(remote.host, 'cdn.islamic.network');

      // Tanpa folder sama sekali juga streaming.
      expect(
        QuranAudioService.sourceFor(
          _surah,
          1,
          reciter: _reciter,
          folder: null,
        ).scheme,
        'https',
      );
    },
  );

  test('pembatalan dibedakan dari kegagalan', () async {
    late AudioDownloadService downloader;
    downloader = service(
      MockClient((_) async {
        // Dibatalkan saat ayat pertama sedang diambil.
        downloader.cancel(_reciter, _surah);
        return http.Response.bytes([1], 200);
      }),
    );

    expect(
      await downloader.download(_reciter, _surah),
      DownloadOutcome.cancelled,
    );
  });

  test('penyimpanan tidak tersedia dilaporkan gagal, bukan melempar', () async {
    final broken = AudioDownloadService(
      client: okClient(),
      directory: () async => throw const FileSystemException('penuh'),
    );

    expect(await broken.download(_reciter, _surah), DownloadOutcome.failed);
    expect(await broken.isComplete(_reciter, _surah), isFalse);
    expect(await broken.storageUsed(_reciter), 0);
    expect(await broken.folderPath(_reciter), isNull);
  });

  testWidgets('dialog dapat dibatalkan tanpa mengunduh apa pun', (
    tester,
  ) async {
    final downloader = service(okClient());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SurahDownloadButton(surah: _surah, service: downloader),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(await downloader.storageUsed(_reciter), 0);
    expect(
      find.byTooltip('Unduh murottal surah ini (Mishary Rashid Alafasy)'),
      findsOneWidget,
    );
  });

  testWidgets('tombol unduh berubah menjadi hapus setelah lengkap', (
    tester,
  ) async {
    final downloader = service(okClient());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SurahDownloadButton(surah: _surah, service: downloader),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Unduh murottal surah ini (Mishary Rashid Alafasy)'),
      findsOneWidget,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    // Ukuran perkiraan ditampilkan sebelum mengunduh.
    expect(find.text('Unduh murottal Al-Ikhlas?'), findsOneWidget);
    expect(find.textContaining('4 ayat'), findsOneWidget);
    await tester.tap(find.text('Unduh'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Hapus murottal offline surah ini'), findsOneWidget);
    expect(await downloader.isComplete(_reciter, _surah), isTrue);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(await downloader.isComplete(_reciter, _surah), isFalse);
  });
}
