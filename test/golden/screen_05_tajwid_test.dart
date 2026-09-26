import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Golden pembaca dengan tajwid aktif (LIQUID_GLASS.md §5, Prompt 3 butir 5):
/// Al-Fatihah dan Al-Baqarah 1–5 di terang, gelap, dan sepia, dengan satu
/// ayat aktif. Diperiksa: tidak ada huruf tertutup nav, tidak ada efek di
/// teks Arab, warna tajwid terbaca di kartu dan di ayat aktif.
Future<void> _prepare(WidgetTester tester, int surah) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({
      'reader_tajweed': true,
      'tajweed_hint_done': true,
    });
    await SharedPreferencesService.init();
    await QuranTextRepository.instance.versesForSurah(surah);
    await TranslationRepository.instance.forSurah(surah);
    await TajweedRepository.instance.forSurah(surah);
    await SuraNamesRepository.load();
    await JuzRepository.load();
    await PageRepository.load();
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}

typedef _Look = ({String name, AppPalette palette, Brightness brightness});

const _looks = <_Look>[
  (name: 'terang', palette: AppPalette.sacred, brightness: Brightness.light),
  (name: 'gelap', palette: AppPalette.sacred, brightness: Brightness.dark),
  (name: 'sepia', palette: AppPalette.sepia, brightness: Brightness.light),
];

void main() {
  for (final (surah, active, slug) in [
    (1, '1:2', 'fatihah'),
    (2, '2:3', 'baqarah'),
  ]) {
    for (final look in _looks) {
      testWidgets('05 tajwid · $slug · ${look.name}', (tester) async {
        await _prepare(tester, surah);
        final audio = QuranAudioService.instance;
        addTearDown(() => audio.playingVerse.value = null);
        tester.view.physicalSize = phone * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(
          top: statusBar * 3,
          bottom: gestureBar * 3,
        );
        tester.view.viewPadding = const FakeViewPadding(
          top: statusBar * 3,
          bottom: gestureBar * 3,
        );
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SacredTheme.themeFor(look.palette, look.brightness),
            home: ReaderScreen(surah: surahCatalog[surah - 1]),
          ),
        );
        await _settle(tester);
        // Ayat aktif: disorot seperti saat murottal diputar. Aliran indeks
        // pemutar yang baru dibuat mengirim null lewat waktu nyata, jadi
        // tunggu dulu lalu isi lagi sampai nilainya bertahan.
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          audio.playingVerse.value = active;
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(audio.playingVerse.value, active);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/05_tajwid_${slug}_${look.name}.png'),
        );
      });
    }
  }
}
