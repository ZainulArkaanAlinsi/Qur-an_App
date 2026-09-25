import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/main.dart' show QuranApp;
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tes kinerja kaca (LIQUID_GLASS.md §7). Angkanya hanya berarti di HP asli
/// dalam mode profile; emulator dan desktop tidak dihitung.
///
///   flutter drive --profile --driver=test_driver/perf_driver.dart \
///     --target=integration_test/glass_perf_test.dart
///
/// Skenario A (gulir pembaca Al-Baqarah 15 detik, tajwid aktif), B (ganti
/// tab 20 kali), dan C (buka/tutup sheet murottal 10 kali), masing-masing di
/// tingkat penuh dan padat. Ringkasan `watchPerformance` ditulis driver ke
/// `build/glass_perf_<skenario>_<tingkat>.json`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const tiers = {'penuh': GlassPreference.full, 'padat': GlassPreference.off};
  const tabs = ['Beranda', 'Qur’an', 'Belajar', 'Hafalan', 'Saya'];

  /// Memberi waktu nyata untuk animasi (splash, rute, sheet) tanpa
  /// bergantung pada pumpAndSettle.
  Future<void> wait(WidgetTester tester, [int millis = 600]) async {
    for (var elapsed = 0; elapsed < millis; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> launch(WidgetTester tester, GlassPreference glass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding.selesai.v1', true);
    await prefs.setBool('reader_tajweed', true);
    await prefs.setBool('tajweed_hint_done', true);
    await prefs.setString('glass_preference', glass.name);
    await SharedPreferencesService.init();
    final controller = AppController();
    await controller.load();
    await tester.pumpWidget(
      QuranApp(controller: controller, ready: Future<void>.value()),
    );
    // Splash minimal 1,4 detik, lalu AppShell.
    await wait(tester, 3000);
    expect(find.text('Beranda'), findsWidgets);
  }

  Future<void> openBaqarah(WidgetTester tester) async {
    await tester.tap(find.text('Qur’an').last);
    await wait(tester);
    // Setelah skenario pertama, Al-Baqarah juga tampil di kartu "terakhir
    // dibaca"; cukup ketuk yang pertama terlihat.
    final baqarah = find.text('Al-Baqarah');
    if (baqarah.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        baqarah.first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.tap(baqarah.first);
    // Teks, terjemahan, dan tajwid dimuat dari aset.
    await wait(tester, 3000);
    expect(find.byType(ScrollablePositionedList), findsOneWidget);
  }

  for (final MapEntry(key: tier, value: glass) in tiers.entries) {
    testWidgets('A · gulir pembaca Al-Baqarah 15 detik · $tier', (
      tester,
    ) async {
      await launch(tester, glass);
      await openBaqarah(tester);
      final list = find.byType(ScrollablePositionedList);
      await binding.watchPerformance(() async {
        final end = DateTime.now().add(const Duration(seconds: 15));
        var flings = 0;
        while (DateTime.now().isBefore(end)) {
          // Enam lemparan turun, lalu enam naik: nav ikut sembunyi/muncul.
          final down = (flings ~/ 6).isEven;
          await tester.fling(list, Offset(0, down ? -500 : 500), 2500);
          await wait(tester, 700);
          flings++;
        }
      }, reportKey: 'A_gulir_pembaca_$tier');
    });

    testWidgets('B · ganti tab 20 kali · $tier', (tester) async {
      await launch(tester, glass);
      await binding.watchPerformance(() async {
        for (var i = 1; i <= 20; i++) {
          await tester.tap(find.text(tabs[i % tabs.length]).last);
          await wait(tester, 500);
        }
      }, reportKey: 'B_ganti_tab_$tier');
    });

    testWidgets('C · buka/tutup sheet murottal 10 kali · $tier', (
      tester,
    ) async {
      await launch(tester, glass);
      await openBaqarah(tester);
      // Sheet murottal dibuka dari bilah mode fokus.
      await tester.tap(find.byTooltip('Mode fokus'));
      await wait(tester);
      await binding.watchPerformance(() async {
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.text('Murottal'));
          await wait(tester, 700);
          await tester.tap(find.byTooltip('Tutup'));
          await wait(tester, 700);
        }
      }, reportKey: 'C_sheet_murottal_$tier');
    });
  }
}
