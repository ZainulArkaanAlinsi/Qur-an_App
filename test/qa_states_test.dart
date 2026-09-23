import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ukuran dan skala teks yang wajib dilalui setiap layar (DESIGN_SPEC §6).
const _layouts = [
  (name: 'ponsel 390 dp', size: Size(390, 844), scale: 1.0),
  (name: 'layar sempit 320 dp', size: Size(320, 640), scale: 1.0),
  (name: 'teks 200%', size: Size(390, 844), scale: 2.0),
  (name: 'lanskap', size: Size(844, 390), scale: 1.0),
];

void main() {
  // Repositori teks menyimpan hasil urainya per zona waktu semu, jadi seluruh
  // sapuan dijalankan dalam satu tes.
  testWidgets(
    'setiap layar bertahan pada layar sempit, teks besar, dan mode gelap',
    (tester) async {
      final today = ReadingProgressService.localDate(DateTime.now());
      SharedPreferences.setMockInitialValues({
        'last_read_surah': 36,
        'last_read_verse_36': 41,
        'reading_seconds_$today': 420,
        'daily_target_seconds': 300,
        'completed_surahs': ['1', '2'],
      });
      await SharedPreferencesService.init();
      final controller = AppController();
      await controller.load();

      // Teks diurai lewat compute(); isolate tidak berjalan di waktu semu.
      await tester.runAsync(() async {
        await QuranTextRepository.instance.versesForSurah(1);
        await TranslationRepository.instance.forSurah(1);
      });
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final screens = <String, Widget>{
        'Beranda': HomeScreen(onOpenQuran: () {}),
        'Qur’an': const QuranLibraryScreen(),
        'Progres': const ProgressScreen(),
        'Pengaturan': const SettingsScreen(),
        'Pembaca': ReaderScreen(surah: surahCatalog.first),
      };

      for (final layout in _layouts) {
        for (final brightness in Brightness.values) {
          for (final entry in screens.entries) {
            await tester.binding.setSurfaceSize(layout.size);
            await tester.pumpWidget(
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) => MaterialApp(
                  theme: SacredTheme.themeFor(controller.palette, brightness),
                  builder: (context, child) => AppScope(
                    controller: controller,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(layout.scale),
                      ),
                      child: child ?? const SizedBox(),
                    ),
                  ),
                  home: Scaffold(body: SafeArea(child: entry.value)),
                ),
              ),
            );
            await tester.pump();
            for (var i = 0; i < 4; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump();
            }

            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} · ${layout.name} · $brightness',
            );

            // Layar berikutnya dibangun dari awal, bukan memakai ulang State.
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
}
