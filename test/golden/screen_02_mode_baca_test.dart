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
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

Future<void> _prepare(WidgetTester tester) => tester.runAsync(() async {
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService.init();
  await QuranTextRepository.instance.versesForSurah(1);
  await QuranTextRepository.instance.versesForSurah(112);
  await TranslationRepository.instance.forSurah(112);
  await TajweedRepository.instance.forSurah(112);
  await SuraNamesRepository.load();
  await JuzRepository.load();
  await PageRepository.load();
});

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// Pembaca Al-Ikhlas lalu lembar Tampilan baca dibuka lewat tombol Aa.
Future<void> _openSheet(
  WidgetTester tester, {
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
}) async {
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
      theme: SacredTheme.themeFor(AppPalette.sacred, variant.brightness),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(variant.textScale)),
        child: app!,
      ),
      home: ReaderScreen(surah: surahCatalog[111]),
    ),
  );
  await _settle(tester);
  await tester.tap(find.byTooltip('Tampilan bacaan'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('02 mode baca · ${variant.suffix}', (tester) async {
      await _prepare(tester);
      await _openSheet(tester, variant: variant);

      expect(tester.takeException(), isNull);
      expect(find.text('Tampilan baca'), findsOneWidget);
      expect(find.text('Kartu ayat'), findsOneWidget);
      expectNotTruncated(tester, [
        'Tampilan baca',
        'Selesai',
        '1 Halaman',
        '2 Halaman',
        'Kartu ayat',
        'Gading',
        'Sepia',
        'Malam',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/02_mode_baca_${variant.suffix}.png'),
      );
    });
  }

  testWidgets('kertas dan tajwid tersimpan', (tester) async {
    await _prepare(tester);
    await _openSheet(tester);

    await tester.tap(find.text('Sepia'));
    await tester.pump();
    expect(SharedPreferencesService.getReaderPaper(), 'sepia');

    await tester.tap(find.bySemanticsLabel('Tajwid berwarna'));
    await tester.pump();
    expect(SharedPreferencesService.getReaderTajweed(), isFalse);

    // Mode halaman belum tersedia: tidak bisa dipilih.
    expect(
      tester.getSemantics(find.bySemanticsLabel('1 Halaman, belum tersedia')),
      matchesSemantics(
        label: '1 Halaman, belum tersedia',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
      ),
    );
  });
}
