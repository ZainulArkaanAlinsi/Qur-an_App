// Tes kinerja kaca (docs/design/v4-liquid-glass/LIQUID_GLASS.md §7).
//
// Jalankan di HP sungguhan dalam mode profile (emulator tidak dihitung):
//
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/glass_perf_test.dart
//
// Ringkasan tiap skenario ditulis ke build/glass_perf.json oleh driver.
// Catat hasilnya (model HP, versi OS, refresh rate, lulus/gagal anggaran)
// di docs/design/v4-liquid-glass/HASIL_KINERJA.md. Jangan mengarang angka.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/murottal/presentation/murottal_sheet.dart';
import 'package:quran_app_2025/main.dart' show QuranApp;
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tingkat yang diukur: penuh dan padat (Efek kaca: Mati).
const _tiers = [GlassPreference.full, GlassPreference.off];

Future<void> _prefs(GlassPreference glass) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding.selesai.v1', true);
  await prefs.setBool('reader_tajweed', true);
  await prefs.setString('glass_preference', glass.name);
  await SharedPreferencesService.init();
}

/// Layar di dalam tema & lingkup kaca yang sama dengan aplikasi.
Widget _host(GlassPreference glass, Widget home) => MaterialApp(
  theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
  builder: (context, child) => GlassScope(
    controller: GlassController(preference: glass),
    child: child!,
  ),
  home: home,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final glass in _tiers) {
    testWidgets('A · gulir Al-Baqarah 15 detik, tajwid aktif · ${glass.name}', (
      tester,
    ) async {
      await _prefs(glass);
      await tester.pumpWidget(
        _host(glass, ReaderScreen(surah: surahCatalog[1])),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final list = find.byType(Scrollable).first;
      await binding.watchPerformance(() async {
        final clock = Stopwatch()..start();
        var down = true;
        while (clock.elapsed < const Duration(seconds: 15)) {
          await tester.fling(list, Offset(0, down ? -500 : 500), 2500);
          await tester.pumpAndSettle();
          down = !down;
        }
      }, reportKey: 'A_gulir_pembaca_${glass.name}');
    });

    testWidgets('B · ganti tab 20 kali · ${glass.name}', (tester) async {
      await _prefs(glass);
      final controller = AppController();
      await controller.load();
      await tester.pumpWidget(
        QuranApp(
          controller: controller,
          ready: Future.value(),
          glass: GlassController(preference: glass),
        ),
      );
      // Splash paling lama 2,5 detik.
      await tester.pumpAndSettle(const Duration(seconds: 4));
      const tabs = ['Qur’an', 'Belajar', 'Hafalan', 'Saya', 'Beranda'];
      await binding.watchPerformance(() async {
        for (var i = 0; i < 20; i++) {
          await tester.tap(find.text(tabs[i % tabs.length]).last);
          await tester.pumpAndSettle();
        }
      }, reportKey: 'B_ganti_tab_${glass.name}');
    });

    testWidgets('C · buka/tutup lembar murottal 10 kali · ${glass.name}', (
      tester,
    ) async {
      await _prefs(glass);
      await tester.pumpWidget(
        _host(
          glass,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showMurottalSheet(
                    context,
                    surah: surahCatalog[0],
                    arabicName: 'الفاتحة',
                    verse: 1,
                  ),
                  child: const Text('Buka murottal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.watchPerformance(() async {
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.text('Buka murottal'));
          await tester.pumpAndSettle();
          // Tutup dengan mengetuk penghalang di atas lembar.
          await tester.tapAt(const Offset(20, 40));
          await tester.pumpAndSettle();
        }
      }, reportKey: 'C_lembar_murottal_${glass.name}');
    });
  }
}
