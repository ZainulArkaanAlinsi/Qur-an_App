import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
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
          // Bentuknya mengikuti respons asli, yang selalu menyebut bahasa.
          {
            'identifier': id,
            'language': 'ar',
            'name': 'اسم $id',
            'englishName': 'Nama $id',
          },
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

    test('mode hemat kuota memilih berkas terkecil lebih dulu', () async {
      final tried = <String>[];
      final repository = ReciterRepository(
        client: MockClient((request) async {
          tried.add(request.url.pathSegments[2]);
          return http.Response('', 200);
        }),
      );

      final resolved = await repository.resolveBitrate(
        const Reciter(identifier: 'ar.x', name: '', englishName: 'X'),
        lowData: true,
      );
      expect(resolved!.bitrate, 64);
      expect(tried, ['64']);
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

  group('penyaringan daftar qari', () {
    // Endpoint mengembalikan semua edisi audio, termasuk audio terjemahan
    // dan riwayat selain Hafs. Dulu semuanya ikut masuk daftar qari.
    const editions = [
      {'identifier': 'ar.alafasy', 'language': 'ar', 'englishName': 'Alafasy'},
      {
        'identifier': 'ar.husary',
        'language': 'ar',
        'englishName': 'Husary Muallim',
      },
      {
        'identifier': 'ar.abdulbasitmujawwad',
        'language': 'ar',
        'englishName': 'Abdul Basit Mujawwad',
      },
      {
        'identifier': 'ar.warsh',
        'language': 'ar',
        'englishName': 'Warsh recitation',
      },
      {
        'identifier': 'en.walk',
        'language': 'en',
        'englishName': 'Ibrahim Walk',
      },
      {'identifier': 'ur.khan', 'language': 'ur', 'englishName': 'Shamshad'},
      {'identifier': 'fr.leclerc', 'language': 'fr', 'englishName': 'Leclerc'},
    ];

    test('audio terjemahan dibuang', () {
      final kept = keepRecitations([
        for (final edition in editions) Map<String, dynamic>.from(edition),
      ]).map((reciter) => reciter.identifier);
      expect(kept, isNot(contains('en.walk')));
      expect(kept, isNot(contains('ur.khan')));
      expect(kept, isNot(contains('fr.leclerc')));
    });

    test('riwayat selain Hafs dibuang', () {
      final kept = keepRecitations([
        for (final edition in editions) Map<String, dynamic>.from(edition),
      ]).map((reciter) => reciter.identifier);
      expect(kept, isNot(contains('ar.warsh')));
      expect(kept, contains('ar.alafasy'));
    });

    test('entri kembar hanya muncul sekali', () {
      final kept = keepRecitations([
        {'identifier': 'ar.alafasy', 'language': 'ar', 'englishName': 'A'},
        {'identifier': 'ar.alafasy', 'language': 'ar', 'englishName': 'A'},
      ]);
      expect(kept, hasLength(1));
    });

    test('entri tanpa identifier tidak menjatuhkan seluruh daftar', () {
      final kept = keepRecitations([
        {'language': 'ar', 'englishName': 'Tanpa id'},
        {'identifier': 'ar.alafasy', 'language': 'ar', 'englishName': 'A'},
      ]);
      expect(kept.single.identifier, 'ar.alafasy');
    });

    test('gaya bacaan dibaca dari nama, bukan ditebak', () {
      expect(Reciter.styleOf('Husary Muallim'), RecitationStyle.muallim);
      expect(Reciter.styleOf('Abdul Basit Mujawwad'), RecitationStyle.mujawwad);
      expect(Reciter.styleOf('Minshawi Murattal'), RecitationStyle.murattal);
      // Tidak disebut berarti belum dipastikan, bukan otomatis murattal.
      expect(Reciter.styleOf('Alafasy'), RecitationStyle.unknown);
    });

    test('cache lama tanpa field baru tetap terbaca', () {
      final reciter = Reciter.fromJson({
        'identifier': 'ar.husary',
        'name': 'الحصري',
        'englishName': 'Husary Muallim',
        'bitrate': 128,
      });
      expect(reciter.identifier, 'ar.husary');
      expect(reciter.bitrate, 128);
      expect(reciter.style, RecitationStyle.muallim);
      expect(reciter.narration, Narration.hafs);
      expect(reciter.provider, AudioProvider.alQuranCloud);
      expect(reciter.hasWordTiming, isFalse);
    });
  });

  group('pemilih qari', () {
    const all = [
      Reciter(
        identifier: 'ar.alafasy',
        name: 'مشاري العفاسي',
        englishName: 'Mishary Rashid Alafasy',
        style: RecitationStyle.murattal,
      ),
      Reciter(
        identifier: 'ar.husary',
        name: 'محمود خليل الحصري',
        englishName: 'Husary Muallim',
        style: RecitationStyle.muallim,
      ),
      Reciter(
        identifier: 'ar.abdulbasit',
        name: 'عبد الباسط',
        englishName: 'Abdul Basit Mujawwad',
        style: RecitationStyle.mujawwad,
      ),
      Reciter(
        identifier: 'ar.shuraim',
        name: 'سعود الشريم',
        englishName: 'Saood Shuraim',
      ),
    ];

    test('pencarian mencocokkan nama Latin tanpa peduli huruf besar', () {
      expect(filterReciters(all, 'HUSARY').map((item) => item.identifier), [
        'ar.husary',
      ]);
      expect(filterReciters(all, 'basit').map((item) => item.identifier), [
        'ar.abdulbasit',
      ]);
    });

    test('pencarian juga mencocokkan nama Arab', () {
      expect(filterReciters(all, 'الحصري').map((item) => item.identifier), [
        'ar.husary',
      ]);
    });

    test('kata kunci kosong mengembalikan semuanya', () {
      expect(filterReciters(all, '   '), hasLength(4));
      expect(filterReciters(all, ''), hasLength(4));
    });

    test('kata kunci tanpa hasil mengembalikan daftar kosong', () {
      expect(filterReciters(all, 'zzz'), isEmpty);
    });

    test('dikelompokkan per gaya, urut sesuai enum', () {
      final groups = groupReciters(all);
      expect(groups.keys.toList(), [
        RecitationStyle.murattal,
        RecitationStyle.mujawwad,
        RecitationStyle.muallim,
        RecitationStyle.unknown,
      ]);
      expect(groups[RecitationStyle.muallim]!.single.identifier, 'ar.husary');
    });

    test('inisial avatar mengabaikan keterangan dalam kurung', () {
      Reciter named(String english, [String arabic = 'قارئ']) =>
          Reciter(identifier: 'x', name: arabic, englishName: english);
      expect(reciterInitials(named('Mahmoud Khalil Al-Husary')), 'MK');
      expect(reciterInitials(named('Husary (Mujawwad)')), 'H');
      expect(reciterInitials(named('Alafasy')), 'A');
      expect(reciterInitials(named('', 'الحصري')), 'ا');
    });

    test('gaya juga dibaca dari identifier penyedia', () {
      final reciter = Reciter.fromEdition({
        'identifier': 'ar.abdulbasitmurattal',
        'name': 'عبد الباسط',
        'englishName': 'Abdul Basit',
      });
      expect(reciter.style, RecitationStyle.murattal);
    });

    test('kelompok kosong tidak ikut muncul', () {
      final groups = groupReciters([all.first]);
      expect(groups.keys, [RecitationStyle.murattal]);
    });
  });
}
