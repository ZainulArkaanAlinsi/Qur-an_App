import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tingkat kualitas kaca (LIQUID_GLASS.md §4) dan cara `LiquidGlass`
/// menerapkannya.
void main() {
  GlassTier resolve({
    GlassPreference preference = GlassPreference.auto,
    GlassTier autoTier = GlassTier.full,
    bool solidPalette = false,
    bool highContrast = false,
    bool disableAnimations = false,
  }) => resolveGlassTier(
    preference: preference,
    autoTier: autoTier,
    solidPalette: solidPalette,
    highContrast: highContrast,
    disableAnimations: disableAnimations,
  );

  group('resolveGlassTier', () {
    test('bawaan: Otomatis, penuh', () {
      expect(resolve(), GlassTier.full);
    });

    test('Otomatis mengikuti pengawas frame', () {
      expect(resolve(autoTier: GlassTier.lite), GlassTier.lite);
      expect(resolve(autoTier: GlassTier.solid), GlassTier.solid);
    });

    test('pilihan pengguna menang atas pengawas', () {
      expect(
        resolve(preference: GlassPreference.full, autoTier: GlassTier.solid),
        GlassTier.full,
      );
      expect(resolve(preference: GlassPreference.lite), GlassTier.lite);
      expect(resolve(preference: GlassPreference.off), GlassTier.solid);
    });

    test('palet dan sistem kontras tinggi selalu padat', () {
      for (final preference in GlassPreference.values) {
        expect(
          resolve(preference: preference, solidPalette: true),
          GlassTier.solid,
        );
        expect(
          resolve(preference: preference, highContrast: true),
          GlassTier.solid,
        );
      }
    });

    test('Kurangi gerak paling tinggi ringan', () {
      expect(resolve(disableAnimations: true), GlassTier.lite);
      expect(
        resolve(preference: GlassPreference.full, disableAnimations: true),
        GlassTier.lite,
      );
      expect(
        resolve(preference: GlassPreference.off, disableAnimations: true),
        GlassTier.solid,
      );
    });
  });

  group('GlassController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
    });

    test('pilihan disimpan di glass_preference', () async {
      final controller = GlassController()..load();
      expect(controller.preference, GlassPreference.auto);
      await controller.setPreference(GlassPreference.lite);
      final reloaded = GlassController()..load();
      expect(reloaded.preference, GlassPreference.lite);
    });

    test('tingkat otomatis hanya turun', () async {
      final controller = GlassController()..load();
      await controller.setAutoTier(GlassTier.lite);
      await controller.setAutoTier(GlassTier.full);
      expect(controller.autoTier, GlassTier.lite);
      await controller.setAutoTier(GlassTier.solid);
      expect((GlassController()..load()).autoTier, GlassTier.solid);
    });
  });

  group('LiquidGlass', () {
    Future<BackdropFilter> pump(
      WidgetTester tester, {
      AppPalette palette = AppPalette.sacred,
      Brightness brightness = Brightness.light,
      GlassController? controller,
      MediaQueryData media = const MediaQueryData(),
    }) async {
      Widget glass = const Center(
        child: SizedBox(
          width: 200,
          height: 64,
          child: LiquidGlass(child: SizedBox.expand()),
        ),
      );
      if (controller != null) {
        glass = GlassScope(controller: controller, child: glass);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: SacredTheme.themeFor(palette, brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: media.highContrast,
              disableAnimations: media.disableAnimations,
            ),
            child: child!,
          ),
          home: BackdropGroup(child: glass),
        ),
      );
      return tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    }

    Size glassSize(WidgetTester tester) =>
        tester.getSize(find.byType(LiquidGlass));

    testWidgets('penuh: blur aktif dengan filter tingkat penuh', (
      tester,
    ) async {
      final filter = await pump(tester);
      expect(filter.enabled, isTrue);
      expect(
        filter.filter,
        same(
          glassFilter(GlassTokens.light.spec(GlassSize.bar, GlassTier.full)),
        ),
      );
      expect(glassSize(tester), const Size(200, 64));
    });

    testWidgets('Kurangi gerak memakai filter ringan', (tester) async {
      final filter = await pump(
        tester,
        media: const MediaQueryData(disableAnimations: true),
      );
      expect(filter.enabled, isTrue);
      expect(
        filter.filter,
        same(
          glassFilter(GlassTokens.light.spec(GlassSize.bar, GlassTier.lite)),
        ),
      );
    });

    testWidgets('palet kontras tinggi: filter mati, ukuran sama', (
      tester,
    ) async {
      final filter = await pump(tester, palette: AppPalette.highContrast);
      expect(filter.enabled, isFalse);
      expect(glassSize(tester), const Size(200, 64));
    });

    testWidgets('sistem kontras tinggi: filter mati', (tester) async {
      final filter = await pump(
        tester,
        media: const MediaQueryData(highContrast: true),
      );
      expect(filter.enabled, isFalse);
    });

    testWidgets('Efek kaca: Mati mematikan filter tanpa mengubah ukuran', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
      final controller = GlassController();
      await controller.setPreference(GlassPreference.off);
      final filter = await pump(tester, controller: controller);
      expect(filter.enabled, isFalse);
      expect(glassSize(tester), const Size(200, 64));
    });

    testWidgets('tanpa ripple Material dan tanpa Opacity', (tester) async {
      await pump(tester, brightness: Brightness.dark);
      final glass = find.byType(LiquidGlass);
      expect(
        find.descendant(of: glass, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: glass, matching: find.byType(Opacity)),
        findsNothing,
      );
    });
  });
}
