import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('progres memakai catatan perangkat dan mengaku soal murottal', (
    tester,
  ) async {
    final today = ReadingProgressService.localDate(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'reading_seconds_$today': 420,
      'daily_target_seconds': 300,
      // Al-Fatihah dan Al-Baqarah selesai: juz 1 dan 2 ikut selesai.
      'completed_surahs': ['1', '2'],
    });
    await SharedPreferencesService.init();

    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: const Scaffold(body: ProgressScreen()),
      ),
    );
    await tester.pump();
    // Batas juz dibaca dari aset, yang hanya jalan di luar waktu semu.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    // Menit membaca berasal dari detik yang tercatat, bukan angka contoh.
    expect(find.text('7 mnt'), findsOneWidget);
    expect(find.text('Target hari ini tercapai.'), findsOneWidget);

    // Waktu mendengar memang belum pernah dicatat; jangan dikarang.
    expect(find.text('Belum dicatat'), findsOneWidget);

    expect(find.text('Juz berikutnya: Juz 3.'), findsOneWidget);
    expect(find.bySemanticsLabel('Juz 1: selesai'), findsOneWidget);
    expect(find.bySemanticsLabel('Juz 3: berikutnya'), findsOneWidget);
    expect(find.bySemanticsLabel('Juz 30: belum'), findsOneWidget);
  });
}
