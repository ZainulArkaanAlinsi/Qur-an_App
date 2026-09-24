import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _ikhlas = surahCatalog[111];

/// Teks, terjemahan, dan tajwid diurai di luar waktu semu (compute/isolate),
/// lalu tersimpan di repositorinya.
Future<void> _prepare(WidgetTester tester, {bool second = true}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({
      if (second)
        'reader_second_translation': jsonEncode(
          suggestedSecondTranslation.toJson(),
        ),
    });
    await SharedPreferencesService.init();
    await QuranTextRepository.instance.versesForSurah(112);
    await TranslationRepository.instance.forSurah(112);
    await TajweedRepository.instance.forSurah(112);
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

/// Seperti pumpGolden, tanpa pumpAndSettle: pembaca menampilkan indikator
/// berputar selama memuat.
Future<void> _pumpReader(
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
      home: ReaderScreen(surah: _ikhlas),
    ),
  );
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('05 kartu · ${variant.suffix}', (tester) async {
      await _prepare(tester);
      await _pumpReader(tester, variant: variant);
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Kartu ayat · 4 ayat'), findsOneWidget);
      expect(find.text('Indonesia + English'), findsOneWidget);
      // Bahasa kedua belum diunduh: ditawarkan sekali.
      expect(find.text('Unduh'), findsOneWidget);
      expectNotTruncated(tester, [
        'Indonesia + English',
        'Tajwid',
        'Kartu ayat · 4 ayat',
        'Al-Ikhlas',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/05_kartu_${variant.suffix}.png'),
      );
    });
  }

  testWidgets('tanpa bahasa kedua: tidak ada tawaran unduh', (tester) async {
    await _prepare(tester, second: false);
    await _pumpReader(tester);
    await _settle(tester);
    expect(find.text('Indonesia'), findsOneWidget);
    expect(find.text('Unduh'), findsNothing);
  });

  testWidgets('chip Tajwid mematikan dan menyimpan pilihan', (tester) async {
    await _prepare(tester);
    await _pumpReader(tester);
    await _settle(tester);
    expect(SharedPreferencesService.getReaderTajweed(), isTrue);
    await tester.tap(find.text('Tajwid'));
    await tester.pump();
    expect(SharedPreferencesService.getReaderTajweed(), isFalse);
    expect(find.text('Warna tajwid dimatikan'), findsOneWidget);
  });
}
