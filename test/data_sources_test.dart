import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/data/audio_repository.dart';
import 'package:quran_app_2025/data/online_translations.dart';
import 'package:quran_app_2025/data/source_fallback.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/prayer_service.dart';

/// Teks uji sengaja memuat spasi di awal/akhir, spasi ganda, dan tanda
/// kutip: semuanya harus tersimpan persis (tanpa trim/replace).
const _verbatim = '  Say, "He is Allah,  [who is] One"  ';

/// Satu edisi fawazahmed0 lengkap (6236 ayat); [skip] menghilangkan satu
/// ayat untuk menguji data tidak lengkap.
String _fawazEdition({String? skip}) => jsonEncode({
  'quran': [
    for (final meta in surahCatalog)
      for (var ayah = 1; ayah <= meta.ayahCount; ayah++)
        if ('${meta.number}:$ayah' != skip)
          {
            'chapter': meta.number,
            'verse': ayah,
            'text': meta.number == 112 && ayah == 1
                ? _verbatim
                : 'teks ${meta.number}:$ayah',
          },
  ],
});

/// Satu surah QuranEnc.
String _quranEncSura(int surah) => jsonEncode({
  'result': [
    for (var ayah = 1; ayah <= surahCatalog[surah - 1].ayahCount; ayah++)
      {
        'sura': '$surah',
        'aya': '$ayah',
        'translation': surah == 112 && ayah == 1
            ? _verbatim
            : 'qe $surah:$ayah',
      },
  ],
});

const _quranEncList = '''
{"translations":[{"key":"english_saheeh","direction":"ltr",
"language_iso_code":"en","version":"1.1.2","title":"English - Saheeh International"}]}
''';

const _fawazList = '''
{"ara_quran":{"name":"ara-quran","author":"x","language":"Arabic","direction":"rtl"},
"eng_ummmuhammad":{"name":"eng-ummmuhammad","author":"Umm Muhammad","language":"English","direction":"ltr"}}
''';

http.Response _json(String body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('quran_sources_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  OnlineTranslations library(MockClient client) => OnlineTranslations(
    client: client,
    directory: () async => temp,
    timeout: const Duration(seconds: 2),
  );

  group('firstAvailable', () {
    test('sumber utama berhasil → tidak menyentuh cadangan', () async {
      var fallbackCalled = false;
      final result = await firstAvailable<int>([
        () async => 1,
        () async {
          fallbackCalled = true;
          return 2;
        },
      ]);
      expect(result.value, 1);
      expect(result.fromFallback, isFalse);
      expect(fallbackCalled, isFalse);
    });

    test('sumber utama gagal → pindah ke cadangan', () async {
      final result = await firstAvailable<int>([
        () async => throw const SocketException('offline'),
        () async => 2,
      ]);
      expect(result.value, 2);
      expect(result.index, 1);
    });

    test('sumber utama timeout → pindah ke cadangan', () async {
      final result = await firstAvailable<int>([
        () => Completer<int>().future, // tidak pernah selesai
        () async => 2,
      ], timeout: const Duration(milliseconds: 50));
      expect(result.value, 2);
      expect(result.fromFallback, isTrue);
    });

    test('semua gagal → SourceUnavailable berisi semua galat', () async {
      await expectLater(
        firstAvailable<int>([
          () async => throw StateError('a'),
          () async => throw StateError('b'),
        ]),
        throwsA(
          isA<SourceUnavailable>().having(
            (e) => e.errors,
            'errors',
            hasLength(2),
          ),
        ),
      );
    });
  });

  group('terjemahan: katalog', () {
    test('QuranEnc dipakai lebih dulu, lalu disimpan untuk luring', () async {
      var online = true;
      final lib = library(
        MockClient((request) async {
          if (!online) throw const SocketException('offline');
          if (request.url.host == 'quranenc.com') return _json(_quranEncList);
          return _json('', 500);
        }),
      );
      final first = await lib.catalog();
      expect(first.fromFallback, isFalse);
      expect(first.value.single.id, 'english_saheeh');
      expect(first.value.single.version, '1.1.2');

      online = false;
      final offline = await lib.catalog();
      expect(offline.value.single.id, 'english_saheeh');
    });

    test(
      'QuranEnc gagal → daftar dari fawazahmed0, tanpa edisi Arab',
      () async {
        final lib = library(
          MockClient((request) async {
            if (request.url.host == 'quranenc.com') return _json('', 503);
            return _json(_fawazList);
          }),
        );
        final result = await lib.catalog();
        expect(result.fromFallback, isTrue);
        expect(result.value.map((e) => e.id), ['eng-ummmuhammad']);
      },
    );

    test('luring tanpa cache → SourceUnavailable', () async {
      final lib = library(
        MockClient((_) async => throw const SocketException('offline')),
      );
      await expectLater(lib.catalog(), throwsA(isA<SourceUnavailable>()));
    });
  });

  group('terjemahan: unduh & cache', () {
    const fawaz = TranslationEdition(
      provider: TranslationProvider.fawazahmed0,
      id: 'eng-ummmuhammad',
      title: 'Umm Muhammad',
      language: 'English',
    );

    test('tersimpan persis, tanpa trim atau normalisasi', () async {
      final lib = library(MockClient((_) async => _json(_fawazEdition())));
      await lib.download(fawaz);

      final saved = await lib.load(fawaz);
      expect(saved, isNotNull);
      expect(saved!.verses[111][0], _verbatim);
      expect(saved.verses.fold<int>(0, (n, s) => n + s.length), 6236);
      expect((await lib.saved()).single.edition, fawaz);
    });

    test('terjemahan tersimpan tetap terbaca saat luring', () async {
      var online = true;
      final lib = library(
        MockClient((_) async {
          if (!online) throw const SocketException('offline');
          return _json(_fawazEdition());
        }),
      );
      await lib.download(fawaz);
      online = false;
      final saved = await lib.load(fawaz);
      expect(saved!.verses[0][0], 'teks 1:1');
    });

    test('data tidak lengkap ditolak dan tidak disimpan', () async {
      final lib = library(
        MockClient((_) async => _json(_fawazEdition(skip: '2:255'))),
      );
      await expectLater(lib.download(fawaz), throwsA(anything));
      expect(await lib.load(fawaz), isNull);
      expect(await lib.saved(), isEmpty);
    });

    test('QuranEnc per surah tersimpan beserta versinya', () async {
      final lib = library(
        MockClient((request) async {
          final surah = int.parse(request.url.pathSegments.last);
          return _json(_quranEncSura(surah));
        }),
      );
      const edition = TranslationEdition(
        provider: TranslationProvider.quranEnc,
        id: 'indonesian_complex',
        title: 'Indonesian',
        language: 'id',
        version: '1.0.5',
      );
      final saved = await lib.download(edition);
      expect(saved, edition);
      final loaded = await lib.load(edition);
      expect(loaded!.verses[111][0], _verbatim);
      expect(loaded.edition.version, '1.0.5');
    });

    test('QuranEnc gagal → padanan yang sama dari fawazahmed0', () async {
      final lib = library(
        MockClient((request) async {
          if (request.url.host == 'quranenc.com') return _json('', 500);
          return _json(_fawazEdition());
        }),
      );
      const saheeh = TranslationEdition(
        provider: TranslationProvider.quranEnc,
        id: 'english_saheeh',
        title: 'English - Saheeh International',
        language: 'en',
      );
      final saved = await lib.download(saheeh);
      expect(saved.provider, TranslationProvider.fawazahmed0);
      expect(saved.id, 'eng-ummmuhammad');
      expect(await lib.load(saved), isNotNull);
    });

    test('hapus menghilangkan cache', () async {
      final lib = library(MockClient((_) async => _json(_fawazEdition())));
      await lib.download(fawaz);
      await lib.remove(fawaz);
      expect(await lib.load(fawaz), isNull);
    });
  });

  group('audio', () {
    const alafasy = Reciter(
      identifier: 'ar.alafasy',
      name: 'مشاري العفاسي',
      englishName: 'Alafasy',
    );

    test('per ayat utama dari cdn.islamic.network', () {
      final uri = AudioRepository.islamicNetworkAyah(alafasy, 1, 1);
      expect(
        uri.toString(),
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
      );
    });

    test('cadangan per ayat dan per surah dari equran.id', () {
      expect(
        AudioRepository.equranAyah('05', 112, 1).toString(),
        'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/112001.mp3',
      );
      expect(
        AudioRepository.equranSurah('05', 9).toString(),
        'https://cdn.equran.id/audio-full/Misyari-Rasyid-Al-Afasi/009.mp3',
      );
      expect(AudioRepository.equranIsSameReciter(alafasy), isTrue);
    });

    test('MP3Quran memilih mushaf riwayat Hafs', () async {
      final repo = AudioRepository(
        client: MockClient(
          (_) async => _json('''
{"reciters":[{"id":123,"moshaf":[
 {"rewaya_id":12,"server":"https://x/kisai/","surah_list":"12,14"},
 {"rewaya_id":1,"server":"https://server8.mp3quran.net/afs/","surah_list":"1,2,12,114"}]}]}
'''),
        ),
      );
      final uri = await repo.mp3QuranSurah(123, 12);
      expect(uri.toString(), 'https://server8.mp3quran.net/afs/012.mp3');
    });

    test('MP3Quran gagal → cadangan equran.id per surah', () async {
      final repo = AudioRepository(
        client: MockClient((request) async {
          if (request.url.host.contains('mp3quran')) return _json('', 500);
          return http.Response('', 200); // HEAD equran.id
        }),
      );
      final result = await repo.surahAudio(alafasy, 1);
      expect(result.fromFallback, isTrue);
      expect(result.value.host, 'cdn.equran.id');
    });

    test('semua sumber audio gagal → SourceUnavailable', () async {
      final repo = AudioRepository(
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      await expectLater(
        repo.surahAudio(alafasy, 1),
        throwsA(isA<SourceUnavailable>()),
      );
    });

    test('EveryAyah tidak dipakai', () {
      expect(
        AudioProvider.values.map((p) => p.name),
        isNot(contains('everyAyah')),
      );
    });
  });

  test('waktu salat AlAdhan memakai method=20 (Kemenag RI)', () {
    expect(PrayerService.methodId, 20);
  });
}
