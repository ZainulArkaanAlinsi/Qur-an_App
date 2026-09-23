import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('daftar Quran dapat dicari dan difilter', (tester) async {
    // Pembacaan aset hanya berjalan di luar waktu semu, jadi setiap kali
    // layar memuat metadata kita beri satu putaran waktu nyata dulu.
    Future<void> loadAssets() async {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: const Scaffold(body: QuranLibraryScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Al-Fatihah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Yasin');
    await tester.pump();
    // Teks yang diketik ikut cocok dengan find.text, jadi yang diperiksa
    // baris daftarnya lewat keterangan yang hanya dimiliki baris itu.
    expect(find.text('Makkiyah · 83 ayat'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Penyaring tempat turun kini menu di dalam kolom cari, bukan chip.
    await tester.tap(find.byTooltip('Saring tempat turun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Madaniyah').last);
    await tester.pumpAndSettle();
    expect(find.text('Al-Fatihah'), findsNothing);
    expect(find.text('Al-Baqarah'), findsOneWidget);

    await tester.tap(find.text('Juz'));
    await tester.pump();
    await loadAssets();
    expect(find.text('Juz 1'), findsOneWidget);

    // Halaman 1 memuat Al-Fatihah; halaman berikutnya sudah Al-Baqarah.
    await tester.tap(find.text('Halaman'));
    await tester.pump();
    await loadAssets();
    expect(find.text('Al-Fatihah'), findsOneWidget);
  });

  test('metadata Juz memiliki 30 batas berurutan', () {
    final boundaries = JuzRepository.parse(
      File('assets/quran/raw/quran-data.xml').readAsStringSync(),
    );
    expect(boundaries, hasLength(30));
    expect((boundaries.first.surah, boundaries.first.verse), (1, 1));
    expect((boundaries.last.surah, boundaries.last.verse), (78, 1));
    expect(
      () => JuzRepository.parse('<juz index="1" sura="1" aya="1"/>'),
      throwsFormatException,
    );
  });

  test('streak memakai target pada tanggal saat sesi dicatat', () async {
    SharedPreferences.setMockInitialValues({
      'reading_seconds_2026-03-01': 300,
      'reading_seconds_2026-03-02': 300,
      'reading_seconds_2026-03-03': 60,
    });
    await SharedPreferencesService.init();

    final progress = ReadingProgressService.read(now: DateTime(2026, 3, 3, 12));
    expect(progress.todaySeconds, 60);
    expect(progress.currentStreak, 2);
    expect(progress.longestStreak, 2);
    expect(progress.totalSeconds, 660);

    await SharedPreferencesService.setDailyTargetSeconds(
      600,
      now: DateTime(2026, 3, 3),
    );
    expect(SharedPreferencesService.getTargetForDate('2026-03-03'), 300);
    expect(SharedPreferencesService.getTargetForDate('2026-03-04'), 600);
  });
}
