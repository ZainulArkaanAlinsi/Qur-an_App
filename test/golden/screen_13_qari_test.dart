import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Edisi seperti yang dikirim Al Quran Cloud (nama dari penyedia, bukan
/// ditulis ulang). `en.walk` adalah audio terjemahan dan harus tersaring.
const _editions = [
  {
    'identifier': 'ar.husary',
    'language': 'ar',
    'name': 'محمود خليل الحصري',
    'englishName': 'Husary',
  },
  {
    'identifier': 'ar.alafasy',
    'language': 'ar',
    'name': 'مشاري العفاسي',
    'englishName': 'Alafasy',
  },
  {
    'identifier': 'ar.abdulbasitmurattal',
    'language': 'ar',
    'name': 'عبد الباسط عبد الصمد المرتل',
    'englishName': 'Abdul Basit',
  },
  {
    'identifier': 'ar.husarymujawwad',
    'language': 'ar',
    'name': 'محمود خليل الحصري (المجود)',
    'englishName': 'Husary (Mujawwad)',
  },
  {
    'identifier': 'ar.mahermuaiqly',
    'language': 'ar',
    'name': 'ماهر المعيقلي',
    'englishName': 'Maher Al Muaiqly',
  },
  {
    'identifier': 'ar.minshawi',
    'language': 'ar',
    'name': 'محمد صديق المنشاوي',
    'englishName': 'Minshawi',
  },
  {
    'identifier': 'ar.saoodshuraym',
    'language': 'ar',
    'name': 'سعود الشريم',
    'englishName': 'Saood bin Ibraaheem Ash-Shuraym',
  },
  {
    'identifier': 'ar.shaatree',
    'language': 'ar',
    'name': 'أبو بكر الشاطري',
    'englishName': 'Abu Bakr Ash-Shaatree',
  },
  {
    'identifier': 'ar.hanirifai',
    'language': 'ar',
    'name': 'هاني الرفاعي',
    'englishName': 'Hani Rifai',
  },
  {
    'identifier': 'en.walk',
    'language': 'en',
    'name': 'Ibrahim Walk',
    'englishName': 'Ibrahim Walk',
  },
];

const _husary = Reciter(
  identifier: 'ar.husary',
  name: 'محمود خليل الحصري',
  englishName: 'Husary',
  bitrate: 128,
);

class _FakePlayer {
  final playing = ValueNotifier<bool>(false);
  final played = <String>[];

  PreviewPlayer get player => PreviewPlayer(
    isPlaying: playing,
    play: (reciter) async {
      played.add(reciter.identifier);
      playing.value = true;
    },
    stop: () async => playing.value = false,
  );
}

/// Menyiapkan preferensi: qari terpilih dan (bila [cached]) daftar qari
/// tersimpan yang masih segar, supaya tidak perlu jaringan.
Future<void> _prepare(WidgetTester tester, {bool cached = true}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({
      if (cached) ...{
        'reciters_cache': jsonEncode([
          for (final reciter in keepRecitations(_editions)) reciter.toJson(),
        ]),
        'reciters_cached_at': DateTime.now().millisecondsSinceEpoch,
      },
    });
    await SharedPreferencesService.init();
    await SharedPreferencesService.setReciter(_husary);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

ReciterRepository _repository({int headStatus = 200}) => ReciterRepository(
  client: MockClient((request) async {
    if (request.method == 'HEAD') return http.Response('', headStatus);
    throw const SocketException('offline');
  }),
);

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('13 qari · ${variant.suffix}', (tester) async {
      await _prepare(tester);
      await pumpGolden(
        tester,
        ReciterPicker(repository: _repository(), player: _FakePlayer().player),
        variant: variant,
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Riwayat Hafs · 9 qari'), findsOneWidget);
      expect(find.text('Ibrahim Walk'), findsNothing);
      expectNotTruncated(tester, [
        'Qari',
        'Saya',
        'Semua',
        'Murattal',
        'Mujawwad',
        'Muallim',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/13_qari_${variant.suffix}.png'),
      );
    });
  }

  group('perilaku', () {
    Future<_FakePlayer> open(
      WidgetTester tester, {
      bool cached = true,
      int headStatus = 200,
    }) async {
      await _prepare(tester, cached: cached);
      final fake = _FakePlayer();
      await pumpGolden(
        tester,
        ReciterPicker(
          repository: _repository(headStatus: headStatus),
          player: fake.player,
        ),
      );
      await _settle(tester);
      return fake;
    }

    testWidgets('qari terpilih di paling atas, bertanda terpilih', (
      tester,
    ) async {
      await open(tester);
      final husary = tester.getTopLeft(find.text('Husary'));
      final alafasy = tester.getTopLeft(find.text('Alafasy'));
      expect(husary.dy, lessThan(alafasy.dy));
      expect(find.bySemanticsLabel(RegExp('^Husary, .*terpilih')), findsOne);
    });

    testWidgets('memilih qari menyimpan setelah bitratenya terbukti ada', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Alafasy'));
      await _settle(tester);
      final saved = SharedPreferencesService.getReciter();
      expect(saved.identifier, 'ar.alafasy');
      expect(saved.bitrate, 128);
      expect(find.bySemanticsLabel(RegExp('^Alafasy, .*terpilih')), findsOne);
    });

    testWidgets('audio tidak ada di server: pilihan lama tetap', (
      tester,
    ) async {
      await open(tester, headStatus: 404);
      await tester.tap(find.text('Alafasy'));
      await _settle(tester);
      expect(SharedPreferencesService.getReciter().identifier, 'ar.husary');
      expect(find.textContaining('Qari sebelumnya tetap dipakai'), findsOne);
    });

    testWidgets('dengar contoh lalu berhenti', (tester) async {
      final fake = await open(tester);
      await tester.tap(find.byTooltip('Dengar contoh Alafasy'));
      await _settle(tester);
      expect(fake.played, ['ar.alafasy']);
      expect(find.byTooltip('Hentikan contoh'), findsOne);

      await tester.tap(find.byTooltip('Hentikan contoh'));
      await _settle(tester);
      expect(fake.playing.value, isFalse);
      expect(find.byTooltip('Hentikan contoh'), findsNothing);
    });

    testWidgets('filter gaya memakai keterangan penyedia', (tester) async {
      await open(tester);
      await tester.tap(find.text('Mujawwad'));
      await _settle(tester);
      expect(find.text('Husary (Mujawwad)'), findsOne);
      expect(find.text('Alafasy'), findsNothing);

      await tester.tap(find.text('Murattal'));
      await _settle(tester);
      expect(find.text('Abdul Basit'), findsOne);

      await tester.tap(find.text('Muallim'));
      await _settle(tester);
      expect(find.text('Belum ada qari muallim di daftar ini'), findsOne);
    });

    testWidgets('pencarian tanpa hasil memberi tahu', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await _settle(tester);
      expect(find.text('Tidak ada qari yang cocok dengan "zzz"'), findsOne);
    });

    testWidgets('luring tanpa cache: qari bawaan + Coba lagi', (tester) async {
      await open(tester, cached: false);
      expect(find.textContaining('butuh internet'), findsOne);
      expect(find.text('Coba lagi'), findsOne);
      expect(find.text('Mishary Rashid Alafasy'), findsOne);
    });
  });
}
