import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Kamis, 24 September 2026, 09:20 — sama dengan mockup V2-Beranda.png.
final _now = DateTime(2026, 9, 24, 9, 20);

final _prayerDay = PrayerDay(
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
);

/// Data perangkat yang meniru isi mockup: Al-Baqarah halaman 2, target
/// 2/5 menit, istiqamah Selasa–Rabu (menunggu hari ini), tahap "Mulai dari
/// mana" selesai, murajaah An-Naba' 1–10 jatuh tempo.
Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({
    'last_read_surah': 2,
    'last_read_verse_2': 1,
  });
  await SharedPreferencesService.init();
  String day(int offset) => ReadingProgressService.localDate(
    DateTime(_now.year, _now.month, _now.day + offset),
  );
  await SharedPreferencesService.setReadingSeconds(day(-2), 300);
  await SharedPreferencesService.setReadingSeconds(day(-1), 320);
  await SharedPreferencesService.setReadingSeconds(day(0), 120);
  await SharedPreferencesService.setLessonCompleted('mulai', true);
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
        dueOn: DateTime(_now.year, _now.month, _now.day),
      ),
    );
  }
}

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

/// Beranda di dalam kerangka yang sama dengan AppShell: SafeArea di atas,
/// tab bar mengambang di bawah.
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: HomeScreen(
                onOpenQuran: () {},
                onOpenLearn: () {},
                prayerLoader: () async => _prayerDay,
                now: () => _now,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              tabs: _tabs,
              currentIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _settleAssets(WidgetTester tester) async {
  // Aset (juz, halaman, kurikulum) dibaca di luar waktu semu.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  // rootBundle menyimpan future hasil muat aset. Kalau future itu dibuat di
  // waktu semu tes pertama, tes berikutnya tidak pernah menerimanya; jadi
  // muat sekali di waktu nyata.
  setUpAll(() async {
    await JuzRepository.load();
    await PageRepository.load();
    await SuraNamesRepository.load();
    await CurriculumRepository.load();
  });

  for (final variant in GoldenVariant.all) {
    testWidgets('01 beranda · ${variant.suffix}', (tester) async {
      await tester.runAsync(_seed);
      await pumpGolden(tester, const _Shell(), variant: variant);
      await _settleAssets(tester);

      expect(tester.takeException(), isNull);
      if (variant.textScale == 1) {
        // Di 2× strip salat ada di bawah lipatan dan belum dirender.
        expect(find.text('Dzuhur 11:45'), findsOneWidget);
        expect(find.text('dalam 2 j 25 m'), findsOneWidget);
        expect(find.text('10 ayat'), findsOneWidget);
        expect(find.text('Lanjutkan belajar'), findsOneWidget);
      }
      expect(find.text('13 Rabiulakhir 1448 H'), findsOneWidget);
      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.text('Halaman 2 · Juz 1 · Ayat 1'), findsOneWidget);
      expect(find.text('MENUNGGU'), findsOneWidget);
      expectNotTruncated(tester, [
        'Lanjutkan',
        'Dzuhur 11:45',
        'dalam 2 j 25 m',
        'Beranda',
        'Qur’an',
        'Belajar',
        'Hafalan',
        'Saya',
        '13 Rabiulakhir 1448 H',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/01_beranda_${variant.suffix}.png'),
      );

      if (variant.textScale != 1) {
        // Bagian bawah di teks besar: HARI INI dan strip salat.
        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNotTruncated(tester, ['Dzuhur 11:45', 'dalam 2 j 25 m']);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/01_beranda_${variant.suffix}_bawah.png'),
        );
      }
    });
  }
}
