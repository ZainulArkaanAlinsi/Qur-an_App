import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/practice_screen.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al-Ikhlas: 4 ayat, cukup kecil untuk diuji utuh.
final _surah = surahCatalog[111];
final _today = DateTime(2026, 9, 24);

Future<void> _pump(WidgetTester tester, {int from = 1, int to = 2}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.light,
      home: PracticeScreen(
        surah: _surah,
        fromAyah: from,
        toAyah: to,
        now: () => _today,
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.text('Memuat ayat…').evaluate().isEmpty) break;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QuranTextRepository.instance.versesForSurah(112);
    await TranslationRepository.instance.forSurah(112);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  testWidgets('judul sesi, lima langkah, dan penilaian tampil', (tester) async {
    await _pump(tester);
    expect(find.text('Al-Ikhlas · Ayat 1'), findsOneWidget);
    expect(find.textContaining('Ziyadah · ayat 1 dari 1'), findsOneWidget);
    for (final step in ['Dengar', 'Baca', 'Tutup', 'Uji', 'Sambung']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Dengarkan 3×'), findsOneWidget);
    for (final rate in ['Salah', 'Ragu', 'Lancar']) {
      expect(find.text(rate), findsOneWidget);
    }
  });

  testWidgets('Tutup membuka separuh, lalu kata demi kata', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Buka kata berikutnya'), findsOneWidget);

    // Buka sampai semua terlihat, lalu tawarkan langkah berikutnya.
    for (var i = 0; i < 10; i++) {
      if (find.text('Buka kata berikutnya').evaluate().isEmpty) break;
      await tester.tap(find.text('Buka kata berikutnya'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Lanjut: Uji'), findsOneWidget);
  });

  testWidgets('ayat pertama tidak punya sambungan, dan itu dikatakan', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Sambung'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak ada ayat sebelumnya'), findsOneWidget);
    expect(find.text('Dengar sambungan'), findsNothing);
  });

  testWidgets('penilaian dicatat ke jadwal lalu pindah ke ayat berikutnya', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Lancar'));
    await tester.pumpAndSettle();

    final first = SharedPreferencesService.getAyahMemorization(112).single;
    expect(first.ayah, 1);
    // Ayat baru yang lancar: jarak naik dari 1 ke 3 hari.
    expect(first.interval, 3);
    expect(
      SharedPreferencesService.getMemorizationStatus(112),
      MemorizationStatus.learning,
    );
    expect(find.text('Al-Ikhlas · Ayat 2'), findsOneWidget);

    await tester.tap(find.text('Salah'));
    await tester.pumpAndSettle();
    expect(find.text('2 ayat selesai'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('surah lengkap menawarkan tanda Hafal di akhir sesi', (
    tester,
  ) async {
    await _pump(tester, from: 1, to: 4);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Lancar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Tandai Al-Ikhlas hafal'));
    await tester.pumpAndSettle();
    expect(
      SharedPreferencesService.getMemorizationStatus(112),
      MemorizationStatus.memorized,
    );
  });

  testWidgets('jumlah ulang 1–10 tersimpan dan dipakai tombol dengar', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Tambah ulangan'));
    await tester.pumpAndSettle();
    expect(find.text('4×'), findsOneWidget);
    expect(find.text('Dengarkan 4×'), findsOneWidget);
    expect(SharedPreferencesService.getHafalanRepeat(), 4);

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('Tambah ulangan'), warnIfMissed: false);
      await tester.pump();
    }
    // Tanpa batas tidak ada lagi: paling banyak 10×, berhenti sendiri.
    expect(find.text('10×'), findsOneWidget);
  });

  test('satu ayat diulang 3× berhenti setelah tiga kali, tidak berputar', () {
    final plan = RangePlan.of(length: 1, repeatCount: 3);
    expect(plan.mode, AudioRepeat.off);
    expect(plan.copies, 3);
    expect(plan.passTarget, 3);
  });
}
