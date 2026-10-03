import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/murottal_screen.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_now_playing_audio.dart';
import 'golden_harness.dart';

/// Murottal v6 (docs/design/v6/screens/20-murottal.md, acuan
/// V6-Murottal.png): Al-Fatihah ayat 5 dari 7, Hudhaify, 0:01 / 0:06.
late Directory _downloads;

AudioDownloadService _service() => AudioDownloadService(
  client: MockClient((_) async => http.Response('', 404)),
  directory: () async => _downloads,
);

Future<void> _settle(WidgetTester tester) async {
  // Teks ayat & nama surah dibaca dari aset di luar waktu semu.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Teks ayat (Arab 25/29) tidak pernah berada di bawah `Opacity` atau
/// `ShaderMask`; `FadeTransition` milik daftar harus diam di 1.
void _expectAyahUntouched(WidgetTester tester) {
  final ayat = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.style?.fontFamily == SacredText.quran &&
        const [25.0, 29.0].contains(widget.style?.fontSize),
  );
  expect(ayat, findsWidgets);
  for (final element in ayat.evaluate()) {
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      expect(widget, isNot(isA<Opacity>()));
      expect(widget, isNot(isA<ShaderMask>()));
      if (widget is FadeTransition) expect(widget.opacity.value, 1);
      return true;
    });
  }
}

Future<void> _check(
  WidgetTester tester, {
  required String file,
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
  AppPalette palette = AppPalette.sacred,
  Map<String, Object> prefs = const {},
  bool playing = true,
  void Function(FakeNowPlayingAudio audio)? after,
  List<String> expected = const [],
}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(prefs);
    await SharedPreferencesService.init();
  });
  final audio = FakeNowPlayingAudio();
  if (playing) audio.play(1, 5, from: 1);
  await pumpGolden(
    tester,
    MurottalScreen(audio: audio, downloadService: _service()),
    variant: variant,
    palette: palette,
  );
  await _settle(tester);
  if (after != null) {
    after(audio);
    await _settle(tester);
  }
  expect(tester.takeException(), isNull);
  for (final text in expected) {
    expect(find.text(text), findsWidgets, reason: text);
  }
  expectNotTruncated(tester, expected);
  if (playing) _expectAyahUntouched(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$file.png'),
  );
}

const _player = [
  'MUROTTAL · PER AYAT',
  'Al-Fatihah',
  'Hudhaify',
  'Teks',
  'Sampul',
  'Ayat 5 dari 7',
  '0:01 / 0:06',
  'DIPUTAR',
  'Timer',
  'Unduh',
  '1–7',
];

void main() {
  setUpAll(() async {
    await QuranTextRepository.instance.versesForSurah(1);
    await TranslationRepository.instance.forSurah(1);
    await SuraNamesRepository.load();
    _downloads = Directory.systemTemp.createTempSync('murottal_golden');
  });
  tearDownAll(() => _downloads.deleteSync(recursive: true));

  final palettes = {
    'light': (Brightness.light, AppPalette.sacred),
    'dark': (Brightness.dark, AppPalette.sacred),
    'sepia': (Brightness.light, AppPalette.sepia),
  };

  for (final mode in ['teks', 'sampul']) {
    for (final MapEntry(key: name, value: (brightness, palette))
        in palettes.entries) {
      testWidgets('20 murottal · $mode · $name', (tester) async {
        await _check(
          tester,
          file: '20_murottal_${mode}_$name',
          variant: GoldenVariant(brightness, 1),
          palette: palette,
          prefs: {'murottal.tampilan': mode},
          expected: [
            ..._player,
            'Ulang',
            'Kecepatan',
            if (mode == 'teks') 'Yang menguasai di Hari Pembalasan.',
          ],
        );
      });
    }
  }

  testWidgets('20 murottal · teks · teks 2.0', (tester) async {
    await _check(
      tester,
      file: '20_murottal_teks_light_x2',
      variant: const GoldenVariant(Brightness.light, 2),
      expected: const ['Ayat 5 dari 7', 'DIPUTAR'],
    );
  });

  testWidgets('20 murottal · galat', (tester) async {
    await _check(
      tester,
      file: '20_murottal_galat_light',
      after: (audio) =>
          audio.fail('Murottal terputus. Periksa koneksi internet.'),
      expected: const [
        'Murottal belum dapat diputar. Periksa koneksi atau unduh surah ini.',
        'Coba lagi',
        'Ayat 5 dari 7',
      ],
    );
  });

  testWidgets('20 murottal · tidak diputar', (tester) async {
    await _check(
      tester,
      file: '20_murottal_tidak_diputar_light',
      playing: false,
      prefs: {'last_read_surah': 18, 'last_read_verse_18': 23},
      expected: const [
        'Murottal sedang tidak diputar',
        'Putar Al-Kahf dari ayat 23',
      ],
    );
  });
}
