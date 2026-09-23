import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dikirim sebagai byte UTF-8: `http.Response(String, …)` tanpa charset
/// memakai latin1 sehingga nama Arab rusak.
http.Response _editions(List<String> identifiers) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'data': [
        for (final id in identifiers)
          {'identifier': id, 'name': 'اسم $id', 'englishName': 'Nama $id'},
      ],
    }),
  ),
  200,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  group('daftar qari', () {
    test('diambil dari provider lalu disimpan ke cache', () async {
      var calls = 0;
      final repository = ReciterRepository(
        client: MockClient((_) async {
          calls++;
          return _editions(['ar.alafasy', 'ar.husary']);
        }),
      );

      final first = await repository.load();
      expect(first.map((r) => r.identifier), ['ar.alafasy', 'ar.husary']);
      expect(first.first.displayName, 'Nama ar.alafasy');

      // Panggilan kedua dilayani cache yang masih segar.
      final second = await repository.load();
      expect(second, first);
      expect(calls, 1);
    });

    test('gagal jaringan memakai cache lama', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reciters_cache',
        jsonEncode([
          {'identifier': 'ar.husary', 'name': 'x', 'englishName': 'Husary'},
        ]),
      );
      await prefs.setInt('reciters_cached_at', 0); // sudah basi

      final repository = ReciterRepository(
        client: MockClient((_) async => http.Response('gagal', 500)),
      );
      final reciters = await repository.load();
      expect(reciters.single.identifier, 'ar.husary');
    });

    test('tanpa cache dan tanpa jaringan tetap memberi qari bawaan', () async {
      final repository = ReciterRepository(
        client: MockClient((_) async => throw const FormatException('offline')),
      );
      expect(await repository.load(), [defaultReciter]);
    });

    test('daftar kosong dari provider tidak menimpa cache', () async {
      final repository = ReciterRepository(
        client: MockClient((_) async => _editions([])),
      );
      expect(await repository.load(), [defaultReciter]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reciters_cache'), isNull);
    });
  });

  group('bitrate', () {
    test('memakai kualitas tertinggi yang tersedia sesuai urutan', () async {
      final tried = <String>[];
      final repository = ReciterRepository(
        client: MockClient((request) async {
          tried.add(request.url.pathSegments[2]);
          // Qari ini hanya punya 64 kbps, seperti ar.abdulsamad di CDN.
          return http.Response(
            '',
            request.url.path.contains('/64/') ? 200 : 403,
          );
        }),
      );

      final resolved = await repository.resolveBitrate(
        const Reciter(identifier: 'ar.x', name: '', englishName: 'X'),
      );
      expect(resolved!.bitrate, 64);
      expect(tried, ['128', '64']);
    });

    test('qari tanpa berkas sama sekali ditolak', () async {
      final repository = ReciterRepository(
        client: MockClient((_) async => http.Response('', 403)),
      );
      final resolved = await repository.resolveBitrate(
        const Reciter(identifier: 'ar.kosong', name: '', englishName: ''),
      );
      expect(resolved, isNull);
    });

    test('bitrate yang sudah diketahui tidak diperiksa ulang', () async {
      final repository = ReciterRepository(
        client: MockClient((_) async => fail('tidak boleh ada permintaan')),
      );
      expect(await repository.resolveBitrate(defaultReciter), defaultReciter);
    });
  });

  group('qari pilihan', () {
    test('bawaan Alafasy dan tersimpan setelah dipilih', () async {
      expect(SharedPreferencesService.getReciter(), defaultReciter);

      const husary = Reciter(
        identifier: 'ar.husary',
        name: 'الحصري',
        englishName: 'Husary',
        bitrate: 64,
      );
      await SharedPreferencesService.setReciter(husary);
      expect(SharedPreferencesService.getReciter(), husary);
    });

    test('URL audio memakai qari dan bitrate pilihan', () async {
      await SharedPreferencesService.setReciter(
        const Reciter(
          identifier: 'ar.minshawi',
          name: '',
          englishName: 'Minshawi',
          bitrate: 128,
        ),
      );
      // 2:255 adalah ayat ke-262 secara global.
      expect(
        QuranAudioService.urlFor(2, 255).toString(),
        'https://cdn.islamic.network/quran/audio/128/ar.minshawi/262.mp3',
      );

      await SharedPreferencesService.setReciter(
        const Reciter(
          identifier: 'ar.abdulsamad',
          name: '',
          englishName: 'Abdul Samad',
          bitrate: 64,
        ),
      );
      expect(
        QuranAudioService.urlFor(1, 1).toString(),
        'https://cdn.islamic.network/quran/audio/64/ar.abdulsamad/1.mp3',
      );
    });

    test('data qari rusak di penyimpanan jatuh ke bawaan', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reciter', 'bukan json');
      await SharedPreferencesService.init();
      expect(SharedPreferencesService.getReciter(), defaultReciter);
    });
  });
}
