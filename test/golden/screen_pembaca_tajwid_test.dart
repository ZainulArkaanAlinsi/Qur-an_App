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

/// Pembaca bertajwid dengan satu ayat aktif (v4 Prompt 3 §5): Al-Fatihah
/// dan Al-Baqarah 1–5 × terang/gelap/sepia. Diperiksa: tidak ada huruf yang
/// tertutup nav dan tidak ada efek di teks Arab.
Future<void> _prepare(WidgetTester tester, int surah) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({'reader_tajweed': true});
    await SharedPreferencesService.init();
    await QuranTextRepository.instance.versesForSurah(surah);
    await QuranTextRepository.instance.versesForSurah(1);
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
}

void main() {
  final palettes = {
    'light': (AppPalette.sacred, Brightness.light),
    'dark': (AppPalette.sacred, Brightness.dark),
    'sepia': (AppPalette.sepia, Brightness.light),
  };
  for (final (name, surah, active) in [('fatihah', 1, 2), ('baqarah', 2, 2)]) {
    for (final MapEntry(key: palette, value: (colors, brightness))
        in palettes.entries) {
      testWidgets('pembaca tajwid · $name · $palette', (tester) async {
        await _prepare(tester, surah);
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
        // Ayat aktif = ayat yang sedang diputar murottal.
        final audio = QuranAudioService.instance;
        audio.queue.value = AudioQueue.from(surah, 1);
        audio.playingVerse.value = '$surah:$active';
        addTearDown(() {
          audio.queue.value = null;
          audio.playingVerse.value = null;
        });
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SacredTheme.themeFor(colors, brightness),
            home: ReaderScreen(surah: surahCatalog[surah - 1]),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/pembaca_tajwid_${name}_$palette.png'),
        );
      });
    }
  }
}
