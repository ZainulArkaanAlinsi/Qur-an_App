import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/practice_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al-Ikhlas: 4 ayat, cukup kecil untuk diuji utuh.
final _surah = surahCatalog[111];

Future<void> _pump(WidgetTester tester) async {
  // Layar tinggi supaya seluruh ayat dan chip status ikut terbangun.
  await tester.binding.setSurfaceSize(const Size(420, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: SacredTheme.light, home: PracticeScreen(surah: _surah)),
  );
  // Teks dan terjemahan dimuat dari aset dengan I/O nyata.
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  testWidgets('menampilkan seluruh ayat surah beserta kontrol latihan', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Latihan Al-Ikhlas'), findsOneWidget);
    expect(find.text('Putar ayat 1–4'), findsOneWidget);
    expect(find.text('Ayat 1'), findsOneWidget);
    expect(find.text('Ayat 4'), findsOneWidget);
    expect(find.text('3×'), findsOneWidget);
    expect(find.text('Tanpa batas'), findsOneWidget);
  });

  testWidgets('sembunyikan teks menutup ayat, ketukan mengintip satu ayat', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Teks disembunyikan'), findsNWidgets(4));

    await tester.tap(find.text('Ayat 1'));
    await tester.pumpAndSettle();
    // Hanya ayat yang diketuk yang terbuka.
    expect(find.text('Teks disembunyikan'), findsNWidgets(3));
    expect(find.text('Ketuk untuk tutup'), findsOneWidget);
  });

  testWidgets('status hafalan dari layar latihan tersimpan', (tester) async {
    await _pump(tester);

    await tester.tap(find.text(MemorizationStatus.memorized.label));
    await tester.pumpAndSettle();

    expect(
      SharedPreferencesService.getMemorizationStatus(_surah.number),
      MemorizationStatus.memorized,
    );
  });

  testWidgets('mempersempit rentang ayat mengurangi kartu yang tampil', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Putar ayat 1–4'), findsOneWidget);

    // Geser ujung kanan rentang ke kiri.
    await tester.drag(find.byType(RangeSlider), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Rentangnya berubah, dan tombol putar mengikuti rentang baru.
    expect(find.text('Putar ayat 1–4'), findsNothing);
    expect(find.textContaining('Putar ayat'), findsOneWidget);
  });
}
