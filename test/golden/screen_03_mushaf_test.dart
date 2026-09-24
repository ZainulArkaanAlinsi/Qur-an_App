import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';
import 'package:quran_app_2025/features/mushaf/presentation/mushaf_screen.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Tata letak dari fixture QF (hanya untuk tes, tidak dibundel ke APK).
final List<MushafWord> _words = [
  for (final row
      in (jsonDecode(
                File(
                  'test/fixtures/qf_mushaf_v2_pages_sample.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['words']
          as List)
    () {
      final r = row as List;
      final key = (r[3] as String).split(':');
      return MushafWord(
        id: r[0] as int,
        page: r[1] as int,
        line: r[2] as int,
        surah: int.parse(key[0]),
        ayah: int.parse(key[1]),
        position: r[4] as int,
        isVerseEnd: r[5] == 'end',
        glyph: r[6] as String,
      );
    }(),
];

Future<MushafPage> _layout(int page) async => buildMushafPage(page, _words);

Future<void> _prepare(WidgetTester tester) => tester.runAsync(() async {
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService.init();
  for (final surah in [1, 112, 113, 114, 110, 111]) {
    await QuranTextRepository.instance.versesForSurah(surah);
    await TajweedRepository.instance.forSurah(surah);
  }
  await SuraNamesRepository.load();
  await JuzRepository.load();
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
  int page = 604,
}) async {
  tester.view.physicalSize = size * 3;
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
      home: MushafScreen(
        initialPage: page,
        layout: _layout,
        onReadingMode: (_) {},
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('03 mushaf · ${variant.suffix}', (tester) async {
      await _prepare(tester);
      await _pump(tester, size: phone, variant: variant);

      final error = tester.takeException();
      expect(error, isNull);
      expect(find.text('Al-Ikhlas – An-Nas'), findsOneWidget);
      expect(find.text('Juz 30 · Halaman 604'), findsOneWidget);
      expect(find.text(RosetteBadge.arabicNumerals(604)), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/03_mushaf_${variant.suffix}.png'),
      );
    });
  }

  testWidgets('04 mushaf dua halaman · landscape', (tester) async {
    await _prepare(tester);
    await _pump(tester, size: phoneLandscape);

    expect(tester.takeException(), isNull);
    // Halaman ganjil di kanan, genap di kiri.
    final right = tester.getCenter(find.text(RosetteBadge.arabicNumerals(603)));
    final left = tester.getCenter(find.text(RosetteBadge.arabicNumerals(604)));
    expect(right.dx, greaterThan(left.dx));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_mushaf2.png'),
    );
  });

  testWidgets('halaman tanpa data layout: pesan jujur, tidak ditebak', (
    tester,
  ) async {
    await _prepare(tester);
    await _pump(tester, size: phone, page: 10);
    expect(find.textContaining('belum bisa ditampilkan persis'), findsOne);
  });
}
