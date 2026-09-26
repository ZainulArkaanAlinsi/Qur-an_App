import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/presentation/session_card.dart';
import 'package:quran_app_2025/features/session/presentation/session_screen.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/session_fakes.dart';
import 'golden_harness.dart';

/// Layar Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §4) di
/// setiap langkah: terang, gelap, sepia, dan teks 2×. Datanya kurikulum dan
/// teks Tanzil asli; pengguna di tahap 2 dengan tahap 1 sudah selesai.
void main() {
  late VerseTexts texts;
  late Curriculum curriculum;
  final tajweed = <int, List<TajweedVerse>>{};
  late Directory documents;

  final variants = [
    (const GoldenVariant(Brightness.light, 1), AppPalette.sacred, 'light'),
    (const GoldenVariant(Brightness.dark, 1), AppPalette.sacred, 'dark'),
    (const GoldenVariant(Brightness.light, 1), AppPalette.sepia, 'sepia'),
    (const GoldenVariant(Brightness.light, 2), AppPalette.sacred, 'light_x2'),
  ];

  setUpAll(() async {
    texts = loadTanzilTexts();
    curriculum = loadCurriculum();
    for (final surah in shortVerseSurahs) {
      tajweed[surah] = await TajweedRepository.instance.forSurah(surah);
    }
  });

  setUp(() => documents = Directory.systemTemp.createTempSync('sesi_golden_'));
  tearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  Future<void> open(
    WidgetTester tester,
    GoldenVariant variant,
    AppPalette palette,
  ) async {
    late SessionStore store;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        'belajar_selesai': ['huruf-hijaiyah'],
      });
      await SharedPreferencesService.init();
      store = SessionStore(
        SharedPreferencesService.instance!,
        documents: () async => documents,
      );
    });
    await pumpGolden(
      tester,
      SessionScreen(
        audio: FakeSessionAudio(),
        recorder: FakeSessionRecorder(),
        store: store,
        now: () => DateTime(2026, 9, 26, 9),
        includeDrafts: false,
        curriculum: Future.value(curriculum),
        loadTexts: (_) async => texts,
        loadTajweed: (surah, ayah) async => tajweed[surah]?[ayah - 1],
        startLevel: 2,
      ),
      variant: variant,
      palette: palette,
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> toTop(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
  }

  Future<void> skip(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tap(tester, find.text('Lewati'));
    }
  }

  for (final (variant, palette, suffix) in variants) {
    testWidgets('19 sesi · kartu beranda · $suffix', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                SessionTodayCard(session: null, onOpen: () {}),
                const SizedBox(height: 16),
                SessionTodayCard(
                  session: const DailySession(
                    date: '2026-09-26',
                    step: SessionStep.findInVerse,
                  ),
                  onOpen: () {},
                ),
                const SizedBox(height: 16),
                SessionTodayCard(
                  session: const DailySession(
                    date: '2026-09-26',
                    step: SessionStep.done,
                    completed: true,
                    tomorrow: 'Bentuk sambung',
                  ),
                  onOpen: () {},
                ),
              ],
            ),
          ),
        ),
        variant: variant,
        palette: palette,
      );
      expectNotTruncated(tester, ['Sesi hari ini', 'Mulai', 'Lanjutkan']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_kartu_$suffix.png'),
      );
    });

    testWidgets('19 sesi · pemanasan · $suffix', (tester) async {
      await open(tester, variant, palette);
      expectNotTruncated(tester, ['Pemanasan', 'Lewati', 'Ulang', 'Tirukan']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_pemanasan_$suffix.png'),
      );
    });

    testWidgets('19 sesi · materi · $suffix', (tester) async {
      await open(tester, variant, palette);
      await skip(tester, 1);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_materi_$suffix.png'),
      );
    });

    testWidgets('19 sesi · temukan · $suffix', (tester) async {
      await open(tester, variant, palette);
      await skip(tester, 2);
      await tap(tester, find.text('Tunjukkan jawaban'));
      await toTop(tester);
      expectNotTruncated(tester, ['Temukan di ayat']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_temukan_$suffix.png'),
      );
    });

    testWidgets('19 sesi · tirukan · $suffix', (tester) async {
      await open(tester, variant, palette);
      await skip(tester, 3);
      await tap(tester, find.bySemanticsLabel('Rekam bacaanku'));
      await tap(tester, find.bySemanticsLabel('Berhenti merekam'));
      await toTop(tester);
      expectNotTruncated(tester, ['Qari', 'Suaraku', 'Dengar & tirukan']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_tirukan_$suffix.png'),
      );
    });

    testWidgets('19 sesi · selesai · $suffix', (tester) async {
      await open(tester, variant, palette);
      await skip(tester, 4);
      await tap(tester, find.text('Sudah mirip'));
      await toTop(tester);
      expectNotTruncated(tester, ['Sudah mirip', 'Masih beda']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_selesai_$suffix.png'),
      );
    });

    testWidgets('19 sesi · selesai hari ini · $suffix', (tester) async {
      await open(tester, variant, palette);
      await skip(tester, 4);
      await tap(tester, find.text('Selesai'));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/19_sesi_tuntas_$suffix.png'),
      );
    });
  }
}
