import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_governor.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengawas frame kaca (LIQUID_GLASS.md §7).
void main() {
  const budget = Duration(microseconds: 16667); // 60 Hz
  const fast = Duration(milliseconds: 8);
  const slow = Duration(milliseconds: 30);

  List<Duration> window({required int late}) => [
    for (var i = 0; i < 120; i++) i < late ? slow : fast,
  ];

  group('GlassFrameJudge', () {
    test('satu jendela buruk belum menurunkan tingkat', () {
      final judge = GlassFrameJudge(budget: budget);
      expect(judge.add(window(late: 20), GlassTier.full), isNull);
    });

    test('dua jendela berturut-turut > 8% → turun satu tingkat', () {
      final judge = GlassFrameJudge(budget: budget);
      expect(judge.add(window(late: 20), GlassTier.full), isNull);
      expect(judge.add(window(late: 20), GlassTier.full), GlassTier.lite);
    });

    test('7,5% belum buruk; jendela baik memutus rangkaian', () {
      final judge = GlassFrameJudge(budget: budget);
      // 9/120 = 7,5% → baik.
      expect(judge.add(window(late: 9), GlassTier.full), isNull);
      expect(judge.add(window(late: 20), GlassTier.full), isNull);
      expect(judge.add(window(late: 0), GlassTier.full), isNull);
      expect(judge.add(window(late: 20), GlassTier.full), isNull);
      expect(judge.add(window(late: 20), GlassTier.full), GlassTier.lite);
    });

    test('lite → solid; solid tidak turun lagi', () {
      final judge = GlassFrameJudge(budget: budget);
      expect(
        judge.add([...window(late: 30), ...window(late: 30)], GlassTier.lite),
        GlassTier.solid,
      );
      expect(
        judge.add([...window(late: 30), ...window(late: 30)], GlassTier.solid),
        isNull,
      );
    });
  });

  group('GlassController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
    });

    test('tingkat otomatis hanya turun & tersimpan untuk versi ini', () async {
      final controller = GlassController(persist: true);
      controller.lowerAutoTier(GlassTier.lite);
      controller.lowerAutoTier(GlassTier.full); // tidak naik lagi
      expect(controller.autoTier, GlassTier.lite);
      await Future<void>.delayed(Duration.zero);
      expect(GlassController.load().autoTier, GlassTier.lite);
    });

    test('versi aplikasi berubah → tingkat otomatis di-reset', () async {
      SharedPreferences.setMockInitialValues({
        'glass_tier_auto': 'solid',
        'glass_tier_auto_version': '0.0.1',
      });
      await SharedPreferencesService.init();
      expect(GlassController.load().autoTier, GlassTier.full);
      await SharedPreferencesService.setGlassAutoTier('solid', appVersion);
      expect(GlassController.load().autoTier, GlassTier.solid);
    });
  });

  testWidgets('kaca terpasang dihitung; pengawas hanya untuk kaca terlihat', (
    tester,
  ) async {
    final controller = GlassController();
    Widget app({required bool glass}) => MaterialApp(
      theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
      home: GlassScope(
        controller: controller,
        child: GlassGovernor(
          controller: controller,
          child: Scaffold(
            body: glass
                ? const LiquidGlass(child: SizedBox(width: 40, height: 40))
                : const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(glass: false));
    expect(GlassPresence.visible.value, 0);
    await tester.pumpWidget(app(glass: true));
    expect(GlassPresence.visible.value, 1);
    await tester.pumpWidget(app(glass: false));
    expect(GlassPresence.visible.value, 0);
  });
}
