import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_governor.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengawas frame kaca (LIQUID_GLASS.md §7).
void main() {
  const slow = Duration(milliseconds: 30);
  const fast = Duration(milliseconds: 8);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  /// Satu jendela 120 frame dengan [slowCount] frame lambat.
  void window(GlassGovernor governor, int slowCount) {
    for (var i = 0; i < 120; i++) {
      governor.record(i < slowCount ? slow : fast);
    }
  }

  testWidgets('dua jendela buruk berturut-turut menurunkan satu tingkat', (
    tester,
  ) async {
    final glass = GlassController()..load();
    final governor = glass.governor..show(60);
    expect(governor.listening, isTrue);

    window(governor, 20); // 16.7% > 8%
    expect(glass.autoTier, GlassTier.full);
    window(governor, 20);
    expect(glass.autoTier, GlassTier.lite);

    window(governor, 20);
    window(governor, 20);
    expect(glass.autoTier, GlassTier.solid);
    // Padat: tidak ada lagi yang bisa diturunkan, pengawas berhenti.
    expect(governor.listening, isFalse);
    expect(SharedPreferencesService.getGlassAutoTier(), GlassTier.solid);
    governor.hide();
  });

  testWidgets('jendela buruk yang diselingi jendela baik tidak menurunkan', (
    tester,
  ) async {
    final glass = GlassController()..load();
    final governor = glass.governor..show(60);
    window(governor, 20);
    window(governor, 5); // 4.2%: baik
    window(governor, 20);
    expect(glass.autoTier, GlassTier.full);
    // Batas 8%: 10/120 = 8.3% buruk, 9/120 = 7.5% baik.
    window(governor, 9);
    window(governor, 9);
    expect(glass.autoTier, GlassTier.full);
    window(governor, 10);
    window(governor, 10);
    expect(glass.autoTier, GlassTier.lite);
    governor.hide();
  });

  testWidgets('hanya mendengar di mode Otomatis dan saat kaca tampil', (
    tester,
  ) async {
    final glass = GlassController()..load();
    final governor = glass.governor;
    expect(governor.listening, isFalse, reason: 'belum ada kaca tampil');
    governor.show(60);
    expect(governor.listening, isTrue);
    await glass.setPreference(GlassPreference.full);
    expect(governor.listening, isFalse);
    window(governor, 60);
    window(governor, 60);
    expect(glass.autoTier, GlassTier.full);
    await glass.setPreference(GlassPreference.auto);
    expect(governor.listening, isTrue);
    governor.hide();
    expect(governor.listening, isFalse);
  });

  test('anggaran mengikuti refresh rate', () {
    final glass = GlassController()..load();
    glass.governor.setRefreshRate(120);
    expect(glass.governor.budget, const Duration(microseconds: 8333));
    glass.governor.setRefreshRate(60);
    expect(glass.governor.budget, const Duration(microseconds: 16667));
    // Nilai aneh (0, tak hingga) dianggap 60 Hz.
    glass.governor.setRefreshRate(0);
    expect(glass.governor.budget, const Duration(microseconds: 16667));
  });

  test(
    'tingkat otomatis di-reset sekali saat versi aplikasi berubah',
    () async {
      SharedPreferences.setMockInitialValues({
        'glass_tier_auto': 'lite',
        'glass_tier_version': '1.8.0',
      });
      await SharedPreferencesService.init();
      final upgraded = GlassController()..load(version: '1.9.0');
      expect(upgraded.autoTier, GlassTier.full);
      await upgraded.setAutoTier(GlassTier.lite);
      // Versi sama: hasil pengawas dipertahankan.
      final again = GlassController()..load(version: '1.9.0');
      expect(again.autoTier, GlassTier.lite);
    },
  );

  testWidgets('GlassGovernorScope berhenti saat rutenya tertutup', (
    tester,
  ) async {
    final glass = GlassController()..load();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            GlassScope(controller: glass, child: child!),
        home: const GlassGovernorScope(child: Text('kaca')),
      ),
    );
    expect(glass.governor.listening, isTrue);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('tanpa kaca')),
    );
    await tester.pumpAndSettle();
    expect(glass.governor.listening, isFalse);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(glass.governor.listening, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(glass.governor.listening, isFalse);
  });
}
