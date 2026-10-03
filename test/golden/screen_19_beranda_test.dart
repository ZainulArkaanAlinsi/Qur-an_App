import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/app_dock.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
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

import '../support/fake_now_playing_audio.dart';
import 'golden_harness.dart';

/// Jumat, 2 Oktober 2026, 10:35 — sama dengan acuan V6-Beranda.png
/// (Dzuhur 11:42 → "1 j 7 m lagi").
final _now = DateTime(2026, 10, 2, 10, 35);

final _prayerDay = PrayerDay(
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

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

String _day(int offset) => ReadingProgressService.localDate(
  DateTime(_now.year, _now.month, _now.day + offset),
);

Future<void> _memorize(int surah, int count, {int daysLate = 0}) async {
  await SharedPreferencesService.setMemorizationStatus(
    surah,
    MemorizationStatus.learning,
  );
  for (var ayah = 1; ayah <= count; ayah++) {
    await SharedPreferencesService.setAyahMemorization(
      surah,
      ayah,
      AyahMemorization(
        surah: surah,
        ayah: ayah,
        interval: 3,
        dueOn: DateTime(_now.year, _now.month, _now.day - daysLate),
      ),
    );
  }
}

/// Satu keadaan Beranda: data perangkat + jadwal salat + murottal.
class _State {
  const _State(
    this.name, {
    required this.seed,
    this.prayer = true,
    this.playing = false,
    this.expect = const [],
  });

  final String name;
  final Future<void> Function() seed;
  final bool prayer;
  final bool playing;

  /// Teks yang wajib tampil utuh di layar pertama.
  final List<String> expect;
}

Future<void> _base(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPreferencesService.init();
}

final _states = <_State>[
  _State(
    'baru',
    seed: () => _base({}),
    expect: [
      'Sesi hari ini',
      'Mulai sesi',
      'Berikutnya Dzuhur 11:42',
      '1 j 7 m lagi',
    ],
  ),
  _State(
    'sesi_berjalan',
    seed: () async {
      await _base({'last_read_surah': 1, 'last_read_verse_1': 3});
      await SharedPreferencesService.setReadingSeconds(_day(0), 120);
      await SessionStore.app!.saveDay(
        DailySession(date: _day(0), step: SessionStep.findInVerse),
      );
      await _memorize(78, 1);
    },
    expect: ['Lanjutkan sesi', 'Lanjutkan'],
  ),
  _State(
    'murajaah_hafalan',
    seed: () async {
      await _base({'last_read_surah': 67, 'last_read_verse_67': 12});
      await SharedPreferencesService.setStartPoint('hafalan');
      for (final offset in [-3, -2, -1]) {
        await SharedPreferencesService.setReadingSeconds(_day(offset), 320);
      }
      await _memorize(78, 10, daysLate: 2);
    },
    expect: ['Mulai murajaah', '10 ayat'],
  ),
  _State(
    'semua_selesai',
    seed: () async {
      await _base({'last_read_surah': 18, 'last_read_verse_18': 23});
      for (final offset in [-4, -3, -2, -1]) {
        await SharedPreferencesService.setReadingSeconds(_day(offset), 320);
      }
      await SharedPreferencesService.setReadingSeconds(_day(0), 420);
      await SessionStore.app!.saveDay(
        DailySession(date: _day(0), step: SessionStep.done, completed: true),
      );
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
            interval: 6,
            dueOn: DateTime(_now.year, _now.month, _now.day + 6),
          ),
        );
        await SharedPreferencesService.addMurajaahDone(_now);
      }
    },
    expect: [
      'Lanjut membaca',
      'Semua target hari ini tercapai. Alhamdulillah.',
    ],
  ),
  _State(
    'diputar',
    seed: () => _base({'last_read_surah': 1, 'last_read_verse_1': 3}),
    playing: true,
    expect: ['DIPUTAR', 'Al-Fatihah · Ayat 3'],
  ),
  _State(
    'luring',
    seed: () => _base({}),
    prayer: false,
    expect: ['Jadwal salat belum dimuat · Coba lagi'],
  ),
  _State(
    'kota_belum_diatur',
    seed: () => _base({'prayer_city': ''}),
    // Kota kosong: jadwal (dan baris Hijriah) memang tidak dimuat.
    prayer: false,
    expect: ['Atur kota untuk jadwal salat'],
  ),
];

/// Beranda di dalam kerangka yang sama dengan AppShell.
class _Shell extends StatelessWidget {
  const _Shell({required this.state, required this.audio});

  final _State state;
  final FakeNowPlayingAudio audio;

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
                prayerLoader: () async => state.prayer ? _prayerDay : null,
                now: () => _now,
                audio: audio,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppDock(
              tabs: _tabs,
              currentIndex: 0,
              onSelected: (_) {},
              audio: audio,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _settleAssets(WidgetTester tester) async {
  // Aset (halaman, kurikulum, nama Arab) dibaca di luar waktu semu.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _check(
  WidgetTester tester,
  _State state, {
  required String file,
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
  AppPalette palette = AppPalette.sacred,
}) async {
  await tester.runAsync(state.seed);
  final audio = FakeNowPlayingAudio();
  if (state.playing) audio.play(1, 3, from: 1);
  await pumpGolden(
    tester,
    _Shell(state: state, audio: audio),
    variant: variant,
    palette: palette,
  );
  await _settleAssets(tester);
  expect(tester.takeException(), isNull);
  expect(
    find.text('21 Rabiulakhir 1448 H'),
    state.prayer ? findsOneWidget : findsNothing,
  );
  for (final text in state.expect) {
    expect(find.text(text, findRichText: true), findsWidgets, reason: text);
  }
  expectNotTruncated(tester, [
    for (final tab in _tabs) tab.label,
    'LANGKAH BERIKUTNYA',
    'HARI INI',
    ...state.expect,
  ]);
  // Paling banyak satu tombol penuh; tidak ada tiga "Lanjutkan".
  expect(find.text('Lanjutkan').evaluate().length, lessThanOrEqualTo(1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$file.png'),
  );
}

void main() {
  // rootBundle menyimpan future hasil muat aset; muat sekali di waktu nyata.
  setUpAll(() async {
    await JuzRepository.load();
    await PageRepository.load();
    await SuraNamesRepository.load();
    await CurriculumRepository.load();
  });

  for (final state in _states) {
    for (final brightness in Brightness.values) {
      final suffix = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('19 beranda · ${state.name} · $suffix', (tester) async {
        await _check(
          tester,
          state,
          file: '19_beranda_${state.name}_$suffix',
          variant: GoldenVariant(brightness, 1),
        );
      });
    }
  }

  final baru = _states.first;
  testWidgets('19 beranda · semua selesai · digulir ke bawah', (tester) async {
    await _check(
      tester,
      _states.firstWhere((s) => s.name == 'semua_selesai'),
      file: '19_beranda_semua_selesai_light',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/19_beranda_semua_selesai_light_bawah.png'),
    );
  });
  testWidgets('19 beranda · baru · sepia', (tester) async {
    await _check(
      tester,
      baru,
      file: '19_beranda_baru_sepia',
      palette: AppPalette.sepia,
    );
  });
  testWidgets('19 beranda · baru · kontras tinggi', (tester) async {
    await _check(
      tester,
      baru,
      file: '19_beranda_baru_kontras_tinggi',
      palette: AppPalette.highContrast,
    );
  });
  testWidgets('19 beranda · baru · teks 2.0', (tester) async {
    await _check(
      tester,
      baru,
      file: '19_beranda_baru_light_x2',
      variant: const GoldenVariant(Brightness.light, 2),
    );
  });
}
