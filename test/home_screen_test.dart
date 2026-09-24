import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 9, 24, 9, 20);

Future<void> _pumpHome(
  WidgetTester tester, {
  VoidCallback? onOpenLearn,
  VoidCallback? onOpenHafalan,
  Future<PrayerDay?> Function()? prayer,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
      home: Scaffold(
        body: HomeScreen(
          onOpenQuran: () {},
          onOpenLearn: onOpenLearn ?? () {},
          onOpenHafalan: onOpenHafalan,
          // Luring kecuali tes memberi jadwal.
          prayerLoader: prayer ?? () async => null,
          now: () => _now,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPreferencesService.init();
}

void main() {
  // rootBundle menyimpan future hasil muat aset; buat di waktu nyata supaya
  // setiap tes menerimanya.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await JuzRepository.load();
    await PageRepository.load();
    await SuraNamesRepository.load();
    await CurriculumRepository.load();
  });

  testWidgets('menampilkan posisi baca dari perangkat, bukan contoh', (
    tester,
  ) async {
    await tester.runAsync(
      () => _prefs({'last_read_surah': 36, 'last_read_verse_36': 41}),
    );
    await _pumpHome(tester);

    expect(find.text('LANJUTKAN MEMBACA'), findsOneWidget);
    expect(find.text(surahCatalog[35].displayName), findsOneWidget);
    expect(find.textContaining('Juz 23'), findsOneWidget);
    expect(find.textContaining('Ayat 41'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
  });

  testWidgets('pengguna baru diajak mulai, bukan "lanjutkan"', (tester) async {
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(tester);

    expect(find.text('MULAI MEMBACA'), findsOneWidget);
    expect(find.text(surahCatalog.first.displayName), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    // Belum ada hafalan: ajakan memulai, tanpa pill jumlah ayat.
    expect(find.text('Mulai hafalan'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ ayat$')), findsNothing);
  });

  testWidgets('luring: jujur soal jadwal salat, tanpa jam atau Hijriah palsu', (
    tester,
  ) async {
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(tester);

    expect(find.text('Jadwal salat butuh koneksi internet.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{4} H$')), findsNothing);
    expect(find.textContaining('dalam '), findsNothing);
  });

  testWidgets('jadwal salat: salat berikutnya dan hitung mundur', (
    tester,
  ) async {
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(
      tester,
      prayer: () async => PrayerDay(
        gregorianDate: DateTime(2026, 9, 24),
        hijriDate: '13 Rabīʿ al-thānī 1448',
        hijriMonth: 'Rabīʿ al-thānī',
        hijriDay: 13,
        hijriMonthNumber: 4,
        hijriYear: 1448,
        prayers: const {
          'Subuh': '04:24',
          'Dzuhur': '11:45',
          'Ashar': '14:54',
          'Maghrib': '17:48',
          'Isya': '18:57',
        },
      ),
    );

    // Bulan ditulis sekali, dalam bahasa Indonesia (dulu tampil dobel).
    expect(find.text('13 Rabiulakhir 1448 H'), findsOneWidget);
    expect(find.text('Dzuhur 11:45'), findsOneWidget);
    expect(find.text('dalam 2 j 25 m'), findsOneWidget);
  });

  testWidgets('murajaah jatuh tempo: jumlah ayat dan membuka tab Hafalan', (
    tester,
  ) async {
    var hafalan = 0;
    await tester.runAsync(() async {
      await _prefs({});
      await SharedPreferencesService.setMemorizationStatus(
        78,
        MemorizationStatus.learning,
      );
      for (var ayah = 1; ayah <= 10; ayah++) {
        await SharedPreferencesService.setAyahMemorization(
          78,
          ayah,
          AyahMemorization(
            surah: 78,
            ayah: ayah,
            interval: 3,
            // Kemarin terlewat: tetap dihitung jatuh tempo.
            dueOn: DateTime(2026, 9, 23),
          ),
        );
      }
    });
    await _pumpHome(tester, onOpenHafalan: () => hafalan++);

    expect(find.text('Murajaah hari ini'), findsOneWidget);
    expect(
      find.text('${surahCatalog[77].displayName} 1–10 · jatuh tempo'),
      findsOneWidget,
    );
    expect(find.text('10 ayat'), findsOneWidget);

    await tester.tap(find.text('Murajaah hari ini'));
    await tester.pump();
    expect(hafalan, 1);
  });

  testWidgets('baris belajar membuka tab Belajar', (tester) async {
    var learn = 0;
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(tester, onOpenLearn: () => learn++);

    await tester.tap(find.text('Lanjutkan belajar'));
    await tester.pump();
    expect(learn, 1);
  });

  test('Hijriah Indonesia kembali ke teks asli bila angkanya tidak ada', () {
    final day = PrayerDay(
      gregorianDate: DateTime(2026, 9, 24),
      hijriDate: '13 Rabīʿ al-thānī 1448',
      hijriMonth: 'Rabīʿ al-thānī',
      prayers: const {},
    );
    expect(day.hijriIndonesian, '13 Rabīʿ al-thānī 1448');
    expect(PrayerDay.hijriMonthsId, hasLength(12));
    expect(PrayerDay.hijriMonthsId[8], 'Ramadan');
  });
}
