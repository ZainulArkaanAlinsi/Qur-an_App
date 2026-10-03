import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
import 'package:quran_app_2025/features/prayer/presentation/prayer_settings_sheet.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_prayer_locator.dart';
import 'golden_harness.dart';

/// Lembar "Waktu salat" (docs/design/v6/screens/22-pengaturan-salat.md):
/// kepala kaca, isi padat.
PrayerDay _day() => PrayerDay(
  gregorianDate: DateTime(2026, 10, 3),
  hijriDate: '',
  hijriMonth: '',
  prayers: const {
    'Subuh': '04:19',
    'Dzuhur': '11:42',
    'Ashar': '14:46',
    'Maghrib': '17:47',
    'Isya': '18:56',
  },
  timezone: 'Asia/Jakarta',
);

/// Layar di belakang lembar, supaya efek kaca kepala terlihat.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        children: [
          Text(
            'Salat',
            style: SacredText.screenTitle.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 12),
          for (final name in PrayerService.prayerNames)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                name,
                style: SacredText.rowTitle.copyWith(color: tokens.ink),
              ),
            ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassSheet<PrayerSettings>(
                context,
                builder: (_) => PrayerSettingsSheet(
                  preview: _day(),
                  locator: FakePrayerLocator(),
                  fetch: (_) async => _day(),
                  onSaved: (_, _) async {},
                ),
              ),
              child: const Text('Buka'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _check(
  WidgetTester tester, {
  required String file,
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
  Map<String, Object> prefs = const {},
  List<String> expected = const [],
}) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(prefs);
    await SharedPreferencesService.init();
  });
  await pumpGolden(tester, const _Host(), variant: variant);
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  for (final text in expected) {
    expect(find.text(text), findsWidgets, reason: text);
  }
  expectNotTruncated(tester, expected);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$file.png'),
  );
}

void main() {
  testWidgets('22 waktu salat · kota · light', (tester) async {
    await _check(
      tester,
      file: '22_waktu_salat_light',
      expected: const [
        'Waktu salat',
        'Simpan',
        'Otomatis',
        'Pilih kota',
        'Kemenag RI',
        'Belum memilih kota: jadwal memakai Jakarta (bawaan).',
      ],
    );
  });

  testWidgets('22 waktu salat · otomatis · dark', (tester) async {
    await _check(
      tester,
      file: '22_waktu_salat_dark',
      variant: const GoldenVariant(Brightness.dark, 1),
      prefs: const {
        'salat.lokasi.mode': 'otomatis',
        'salat.lokasi.koordinat': '-6.3,107.15',
        'salat.koreksi': '2,0,0,0,0',
      },
      expected: const [
        'Waktu salat',
        'Lokasi sekarang',
        '-6,3, 107,15 · Asia/Jakarta',
        'Perbarui',
        'Kemenag RI',
      ],
    );
  });

  testWidgets('22 waktu salat · kota · teks 2.0', (tester) async {
    await _check(
      tester,
      file: '22_waktu_salat_light_x2',
      variant: const GoldenVariant(Brightness.light, 2),
      prefs: const {'prayer_city': 'Bandung', 'prayer_country': 'Indonesia'},
      expected: const ['Waktu salat', 'Simpan', 'Otomatis', 'Pilih kota'],
    );
  });
}
