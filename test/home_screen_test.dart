import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beranda v6 (docs/design/v6/screens/19-beranda.md): perilaku, bukan
/// piksel (piksel ada di golden 19_beranda_*).
final _now = DateTime(2026, 10, 2, 10, 35);

final _day = PrayerDay(
  gregorianDate: DateTime(2026, 10, 2),
  hijriDate: '21 Rabīʿ al-thānī 1448',
  hijriMonth: 'Rabīʿ al-thānī',
  hijriDay: 21,
  hijriMonthNumber: 4,
  hijriYear: 1448,
  prayers: const {
    'Subuh': '04:22',
    'Dzuhur': '11:42',
    'Ashar': '14:50',
    'Maghrib': '17:49',
    'Isya': '18:58',
  },
);

Future<void> _pumpHome(
  WidgetTester tester, {
  VoidCallback? onOpenLearn,
  VoidCallback? onOpenHafalan,
  PrayerDay? prayer,
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
          prayerLoader: () async => prayer,
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
  // Pergantian isi kartu memakai AnimatedSwitcher 260 ms.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPreferencesService.init();
}

Future<void> _memorizeDue() async {
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
        dueOn: DateTime(2026, 10, 2),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await JuzRepository.load();
    await PageRepository.load();
    await SuraNamesRepository.load();
    await CurriculumRepository.load();
  });

  testWidgets('pengguna baru: satu langkah "Sesi hari ini", bukan tiga '
      '"Lanjutkan"', (tester) async {
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(tester);
    expect(find.text('LANGKAH BERIKUTNYA'), findsOneWidget);
    expect(find.text('Sesi hari ini'), findsOneWidget);
    expect(find.text('Mulai sesi'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsNothing);
    expect(
      find.text('Hari pertama. Lima menit membaca sudah cukup untuk mulai.'),
      findsOneWidget,
    );
    // Belum pernah menghafal: cincin Murajaah tidak ditampilkan.
    expect(find.text('Murajaah'), findsNothing);
  });

  testWidgets('luring: jujur soal jadwal salat, tanpa jam atau Hijriah palsu', (
    tester,
  ) async {
    await tester.runAsync(() => _prefs({}));
    await _pumpHome(tester);
    expect(find.text('Jadwal salat belum dimuat · Coba lagi'), findsOneWidget);
    expect(find.textContaining('Rabiulakhir'), findsNothing);
    expect(find.textContaining('Dzuhur'), findsNothing);
  });

  testWidgets(
    'jadwal salat: horizon dengan salat berikutnya dan hitung mundur',
    (tester) async {
      await tester.runAsync(() => _prefs({}));
      await _pumpHome(tester, prayer: _day);
      expect(find.text('21 Rabiulakhir 1448 H'), findsOneWidget);
      expect(
        find.text('Berikutnya Dzuhur 11:42', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1 j 7 m lagi'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Salat berikutnya Dzuhur, pukul 11.42, 1 jam 7 menit lagi',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('titik mulai hafalan + murajaah: kartu membuka tab Hafalan', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _prefs({});
      await SharedPreferencesService.setStartPoint('hafalan');
      await _memorizeDue();
    });
    var hafalan = 0;
    await _pumpHome(tester, onOpenHafalan: () => hafalan++);
    expect(find.text('10 ayat'), findsOneWidget);
    await tester.tap(find.text('Mulai murajaah'));
    await tester.pump();
    expect(hafalan, 1);
  });

  testWidgets('sesi selesai: bacaan jadi langkah utama, "Sesi besok" ke '
      'tab Belajar', (tester) async {
    await tester.runAsync(() async {
      await _prefs({'last_read_surah': 18, 'last_read_verse_18': 23});
      await SessionStore.app!.saveDay(
        DailySession(
          date: ReadingProgressService.localDate(_now),
          step: SessionStep.done,
          completed: true,
        ),
      );
    });
    var learn = 0;
    await _pumpHome(tester, onOpenLearn: () => learn++);
    expect(find.text('Lanjut membaca'), findsOneWidget);
    expect(find.text('SESI BESOK'), findsOneWidget);
    await tester.tap(find.text('SESI BESOK'));
    await tester.pump();
    expect(learn, 1);
  });
}
