import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/practice_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _today = DateTime(2026, 9, 24);

/// Seperti V2-SesiHafalan.png: An-Naba’ ziyadah 1–5, sekarang ayat 3,
/// langkah Tutup (Dengar & Baca sudah dilalui).
Future<void> _toMockupState(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('Lancar'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Tutup'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await QuranTextRepository.instance.versesForSurah(78);
    await TranslationRepository.instance.forSurah(78);
  });

  for (final variant in GoldenVariant.all) {
    testWidgets('11 sesi hafalan · ${variant.suffix}', (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferencesService.init();
      });
      await pumpGolden(
        tester,
        PracticeScreen(
          surah: surahCatalog[77],
          fromAyah: 1,
          toAyah: 5,
          now: () => _today,
        ),
        variant: variant,
      );
      await _toMockupState(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('An-Naba’ · Ayat 3'), findsOneWidget);
      expect(find.text('Buka kata berikutnya'), findsOneWidget);
      expectNotTruncated(tester, [
        'Dengar',
        'Baca',
        'Tutup',
        'Uji',
        'Sambung',
        'Salah',
        'Ragu',
        'Lancar',
        'Buka kata berikutnya',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/11_sesi_hafalan_${variant.suffix}.png'),
      );
    });
  }
}
