import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_locator.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_settings_store.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
import 'package:quran_app_2025/features/prayer/presentation/prayer_settings_sheet.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_prayer_locator.dart';

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

/// Lembar Waktu salat (22-pengaturan-salat.md "Selesai jika": tes widget).
void main() {
  late FakePrayerLocator locator;
  late List<PrayerSettings> fetched;
  late List<PrayerSettings> rescheduled;
  late bool failFetch;
  PrayerSettings? result;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    locator = FakePrayerLocator();
    fetched = [];
    rescheduled = [];
    failFetch = false;
    result = null;
  });

  Future<void> open(WidgetTester tester, {PrayerDay? preview}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showGlassSheet<PrayerSettings>(
                    context,
                    builder: (_) => PrayerSettingsSheet(
                      preview: preview,
                      locator: locator,
                      fetch: (settings) async {
                        fetched.add(settings);
                        if (failFetch) throw const SocketException('luring');
                        return _day();
                      },
                      onSaved: (day, settings) async =>
                          rescheduled.add(settings),
                    ),
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('izin ditolak permanen: pesan + buka pengaturan, tetap bisa '
      'pilih kota lalu simpan', (tester) async {
    locator = FakePrayerLocator(
      access: LocationAccess.denied,
      afterRequest: LocationAccess.deniedForever,
    );
    await open(tester);
    await tapAndSettle(tester, find.text('Otomatis'));
    await tapAndSettle(tester, find.text('Pakai lokasi sekarang'));
    expect(locator.requests, 1);
    expect(
      find.text(
        'Izin lokasi ditolak. Pilih kota secara manual atau buka '
        'Pengaturan HP.',
      ),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('Buka pengaturan'));
    expect(locator.settingsOpened, 1);

    // Tombol "Pilih kota" di pesan (yang pertama adalah segmen).
    await tapAndSettle(tester, find.text('Pilih kota').last);
    await tester.enterText(find.byType(TextField).first, 'Bandung');
    await tester.pump();
    await tapAndSettle(tester, find.text('Simpan'));

    expect(fetched.single.mode, PrayerLocationMode.city);
    expect(fetched.single.city, 'Bandung');
    expect(rescheduled.single.city, 'Bandung');
    expect(result?.city, 'Bandung');
    expect(find.text('Waktu salat'), findsNothing);
    expect(SharedPreferencesService.getPrayerCity(), 'Bandung');
  });

  testWidgets('otomatis: koordinat dibulatkan, simpan → pengingat '
      'dijadwalkan ulang', (tester) async {
    locator = FakePrayerLocator(position: (-6.2149, 106.8451));
    final revision = PrayerSettingsStore.revision.value;
    await open(tester);
    await tapAndSettle(tester, find.text('Otomatis'));
    await tapAndSettle(tester, find.text('Pakai lokasi sekarang'));
    expect(find.text('Lokasi sekarang'), findsOneWidget);
    expect(find.text('-6,225, 106,85'), findsOneWidget);
    expect(find.text(PrayerSettingsSheet.privacyNote), findsOneWidget);

    await tapAndSettle(tester, find.text('Simpan'));
    final saved = fetched.single;
    expect(saved.usesCoordinates, isTrue);
    expect(saved.coordinates!.storage, '-6.225,106.85');
    expect(rescheduled, [saved]);
    expect(PrayerSettingsStore.revision.value, revision + 1);
    expect(SharedPreferencesService.getPrayerLocationMode(), 'otomatis');
    expect(SharedPreferencesService.getPrayerCoordinates(), '-6.225,106.85');
  });

  testWidgets('jadwal gagal dimuat: setelan tidak disimpan, pesan tampil', (
    tester,
  ) async {
    failFetch = true;
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Kota Salah');
    await tester.pump();
    await tapAndSettle(tester, find.text('Simpan'));
    expect(find.textContaining('belum bisa dimuat'), findsOneWidget);
    expect(find.text('Waktu salat'), findsOneWidget);
    expect(rescheduled, isEmpty);
    expect(SharedPreferencesService.hasPrayerCity(), isFalse);
  });

  testWidgets('kota kosong: Simpan non-aktif', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    await tester.tap(find.text('Simpan'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fetched, isEmpty);
    expect(find.text('Waktu salat'), findsOneWidget);
  });

  testWidgets('metode, Asar, dan koreksi menit ikut tersimpan; jam koreksi '
      'tampil langsung', (tester) async {
    await open(tester, preview: _day());
    await tapAndSettle(tester, find.text('JAKIM Malaysia'));
    await tapAndSettle(tester, find.text('Hanafi'));
    await tapAndSettle(tester, find.text('Koreksi menit'));
    expect(find.text('04:19'), findsOneWidget);
    final plus = find.bySemanticsLabel('Subuh ditambah satu menit');
    await tapAndSettle(tester, plus);
    await tapAndSettle(tester, plus);
    expect(find.text('04:21'), findsOneWidget);
    expect(find.text('Subuh +2'), findsOneWidget);

    await tapAndSettle(tester, find.text('Simpan'));
    final saved = fetched.single;
    expect(saved.method, 17);
    expect(saved.school, 1);
    expect(saved.tune, [2, 0, 0, 0, 0]);
    expect(SharedPreferencesService.getPrayerTune(), '2,0,0,0,0');
  });

  testWidgets('kota terakhir dipakai bisa dipilih ulang', (tester) async {
    await PrayerSettingsStore.save(
      const PrayerSettings(city: 'Makassar', country: 'Indonesia'),
    );
    await PrayerSettingsStore.save(
      const PrayerSettings(city: 'Bandung', country: 'Indonesia'),
    );
    await open(tester);
    TextEditingController city() =>
        tester.widget<TextField>(find.byType(TextField).first).controller!;
    expect(city().text, 'Bandung');
    await tapAndSettle(tester, find.text('Makassar · Indonesia'));
    expect(city().text, 'Makassar');
  });
}
