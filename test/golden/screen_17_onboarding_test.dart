import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/onboarding/presentation/onboarding_screen.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Onboarding v3 (docs/design/v3/screens/17-onboarding.md): halaman 1–4
/// terang/gelap/teks 2×, dan dua frame tengah geser (gerak_*.png).
void main() {
  setUpAll(() async {
    // Dataset dimuat sekali di luar waktu semu; layar memakai cache-nya.
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    await QuranTextRepository.instance.versesForSurah(2);
    await TranslationRepository.instance.forSurah(2);
    await TajweedRepository.instance.forSurah(2);
    await CurriculumRepository.load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await loadImages(tester);
  }

  Future<PageController> pumpAt(
    WidgetTester tester,
    int page,
    GoldenVariant variant,
  ) async {
    final controller = PageController(initialPage: page);
    addTearDown(controller.dispose);
    await pumpGolden(
      tester,
      OnboardingScreen(controller: controller, onDone: (_) {}),
      variant: variant,
    );
    await settle(tester);
    return controller;
  }

  for (final variant in GoldenVariant.all) {
    for (var page = 0; page < OnboardingScreen.pageCount; page++) {
      testWidgets('17 onboarding · halaman ${page + 1} · ${variant.suffix}', (
        tester,
      ) async {
        await pumpAt(tester, page, variant);
        expect(tester.takeException(), isNull);
        // Halaman selebar layar dan bisa disentuh (bukan kanvas kosong).
        expect(tester.getSize(find.byType(PageView)), phone);
        expectNotTruncated(tester, [
          'Lewati',
          'Lanjut',
          'Mulai',
          'Belum bisa membaca huruf Arab',
          'Sudah bisa, ingin lancar tajwid',
          'Ingin fokus menghafal',
        ]);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/17_onboarding_${page + 1}_${variant.suffix}.png',
          ),
        );
      });
    }
  }

  // Frame tengah geser: page 0.5 (1→2) dan 1.3 (2→3), seperti gerak_*.png.
  // Jari masih menahan geseran, jadi fisika belum menarik ke halaman
  // terdekat.
  for (final (name, from, page) in [
    ('1_ke_2_50', 0, .5),
    ('2_ke_3_30', 1, 1.3),
  ]) {
    testWidgets('17 onboarding · geser $name', (tester) async {
      const variant = GoldenVariant(Brightness.light, 1);
      final controller = await pumpAt(tester, from, variant);
      final gesture = await tester.startGesture(const Offset(200, 600));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(Offset(-(page - controller.page!) * phone.width, 0));
      await tester.pump();
      await loadImages(tester);
      expect(controller.page, closeTo(page, .001));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/17_onboarding_geser_$name.png'),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }
}
