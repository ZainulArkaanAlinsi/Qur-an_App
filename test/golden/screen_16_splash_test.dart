import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/onboarding/presentation/splash_screen.dart';

import 'golden_harness.dart';

/// Frame akhir splash animasi (docs/design/v3/screens/16-splash.md,
/// V3-Splash.png / V3-Splash-Gelap.png).
void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('16 splash · frame akhir · ${variant.suffix}', (tester) async {
      final ready = Completer<void>();
      var finished = false;
      await pumpGolden(
        tester,
        SplashScreen(ready: ready.future, onFinished: () => finished = true),
        variant: variant,
      );
      // Animasi mulai paling lambat 300 ms kemudian; lini waktu 1300 ms.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1350));
      await loadImages(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('BACA · BELAJAR · HAFAL'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/16_splash_${variant.suffix}.png'),
      );

      // Batas maksimal 2,5 detik: tetap lanjut walau belum siap.
      await tester.pump(const Duration(seconds: 3));
      expect(finished, isTrue);
    });
  }
}
