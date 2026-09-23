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
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Satu tes untuk semuanya: repositori teks menyimpan hasil urainya per zona
  // waktu semu, sehingga tes kedua di berkas yang sama akan menggantung.
  testWidgets('setiap tombol ikon punya label untuk pembaca layar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'last_read_surah': 36,
      'completed_surahs': ['1'],
    });
    await SharedPreferencesService.init();
    final controller = AppController();
    await controller.load();
    await tester.runAsync(() async {
      await QuranTextRepository.instance.versesForSurah(1);
      await TranslationRepository.instance.forSurah(1);
    });
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final screens = <String, Widget>{
      'Beranda': HomeScreen(onOpenQuran: () {}, onOpenLearn: () {}),
      'Qur’an': const QuranLibraryScreen(),
      'Progres': const ProgressScreen(),
      'Pengaturan': const SettingsScreen(),
      'Pembaca': ReaderScreen(surah: surahCatalog.first),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
            theme: SacredTheme.themeFor(controller.palette, Brightness.light),
            builder: (context, child) => AppScope(
              controller: controller,
              child: child ?? const SizedBox(),
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

      final unlabelled = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .where((button) => (button.tooltip ?? '').trim().isEmpty)
          .toList();
      expect(
        unlabelled,
        isEmpty,
        reason:
            '${entry.key}: ${unlabelled.length} tombol ikon tanpa tooltip, '
            'sehingga TalkBack hanya menyebutnya "tombol".',
      );

      await tester.pumpWidget(const SizedBox());
    }
  });
}
