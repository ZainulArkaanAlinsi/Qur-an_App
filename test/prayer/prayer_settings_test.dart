import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_locator.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_reminders.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_settings_store.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
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

void main() {
  group('pembulatan koordinat (kisi 0,025°)', () {
    test('dibulatkan ke kisi terdekat, maks 3 desimal', () {
      final point = Coordinates.rounded(-6.2149, 106.8451);
      expect(point.latitude, -6.225);
      expect(point.longitude, 106.85);
      expect(point.storage, '-6.225,106.85');
      expect(point.display, '-6,225, 106,85');
      expect(Coordinates.rounded(-6.2, 107.1626).storage, '-6.2,107.175');
      // Dekat nol tidak tertulis "-0".
      expect(Coordinates.rounded(0.004, -0.0124).storage, '0,0');
    });

    test('tidak lebih halus dari kisi: geser 1 km tetap titik yang sama', () {
      // 0,009° ≈ 1 km di khatulistiwa.
      expect(
        Coordinates.rounded(-6.205, 106.851),
        Coordinates.rounded(-6.205 + .009, 106.851 + .009),
      );
    });

    test('baca dari preferensi; nilai rusak = null', () {
      expect(Coordinates.parse('-6.2,106.85'), const Coordinates(-6.2, 106.85));
      expect(Coordinates.parse('rusak'), isNull);
      expect(Coordinates.parse('91,0'), isNull);
      expect(Coordinates.parse(null), isNull);
    });

    test('jarak haversine', () {
      const jakarta = Coordinates(-6.2, 106.85);
      const bandung = Coordinates(-6.925, 107.6);
      expect(jakarta.distanceKm(bandung), closeTo(115, 5));
      expect(jakarta.distanceKm(jakarta), 0);
    });
  });

  group('permintaan AlAdhan', () {
    final day = DateTime(2026, 10, 3);

    test('mode kota: timingsByCity + method + school; tanpa tune bila 0', () {
      final uri = const PrayerSettings(
        city: 'Bandung',
        country: 'Indonesia',
      ).uriFor(day);
      expect(uri.host, 'api.aladhan.com');
      expect(uri.path, '/v1/timingsByCity/03-10-2026');
      expect(uri.queryParameters, {
        'city': 'Bandung',
        'country': 'Indonesia',
        'method': '20',
        'school': '0',
      });
    });

    test('mode otomatis: timings + koordinat yang sudah dibulatkan', () {
      final uri = PrayerSettings(
        mode: PrayerLocationMode.auto,
        coordinates: Coordinates.rounded(-6.2149, 106.8451),
        method: 3,
        school: 1,
      ).uriFor(day);
      expect(uri.path, '/v1/timings/03-10-2026');
      expect(uri.queryParameters['latitude'], '-6.225');
      expect(uri.queryParameters['longitude'], '106.85');
      expect(uri.queryParameters['method'], '3');
      expect(uri.queryParameters['school'], '1');
      expect(uri.queryParameters.containsKey('city'), isFalse);
    });

    test('otomatis tanpa koordinat jatuh ke kota', () {
      final uri = const PrayerSettings(
        mode: PrayerLocationMode.auto,
      ).uriFor(day);
      expect(uri.path, '/v1/timingsByCity/03-10-2026');
      expect(uri.queryParameters['city'], 'Jakarta');
    });

    test('tune: 9 nilai Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Sunset,Isha,'
        'Midnight', () {
      const settings = PrayerSettings(tune: [2, -1, 3, 0, 4]);
      expect(settings.tuneParam, '0,2,0,-1,3,0,0,4,0');
      expect(
        settings.uriFor(day).queryParameters['tune'],
        '0,2,0,-1,3,0,0,4,0',
      );
    });

    test('ID metode sesuai daftar resmi AlAdhan (/v1/methods)', () {
      expect(
        {for (final m in prayerMethods) m.label: m.id},
        {
          'Kemenag RI': 20,
          'Muslim World League': 3,
          'Umm al-Qura, Makkah': 4,
          'Otoritas Mesir': 5,
          'JAKIM Malaysia': 17,
          'MUIS Singapura': 11,
          'ISNA': 2,
        },
      );
      expect(prayerMethods.first.id, PrayerSettings.defaultMethod);
      expect(prayerMethodOf(999).id, 20);
    });
  });

  group('kunci simpanan jadwal', () {
    const base = PrayerSettings(city: 'Bandung', country: 'Indonesia');

    test('berubah saat tempat, metode, Asar, atau koreksi berubah', () {
      final keys = {
        base.cacheKey,
        base.copyWith(city: 'Garut').cacheKey,
        base.copyWith(method: 3).cacheKey,
        base.copyWith(school: 1).cacheKey,
        base.copyWith(tune: const [0, 0, 0, 0, 2]).cacheKey,
        base
            .copyWith(
              mode: PrayerLocationMode.auto,
              coordinates: const Coordinates(-6.9, 107.6),
            )
            .cacheKey,
      };
      expect(keys, hasLength(6));
    });

    test('ejaan kota tidak peka huruf besar & spasi', () {
      expect(
        base.cacheKey,
        const PrayerSettings(city: ' bandung ', country: 'INDONESIA').cacheKey,
      );
    });

    test('koreksi dari preferensi dibatasi ±10, nilai rusak = 0', () {
      expect(PrayerSettings.parseTune('1,-2,30,x'), [1, -2, 10, 0, 0]);
      expect(PrayerSettings.parseTune(null), PrayerSettings.noTune);
    });
  });

  group('PrayerSettingsStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
    });

    test('pengguna baru: Jakarta bawaan, mode kota, Kemenag', () {
      final settings = PrayerSettingsStore.load();
      expect(settings.mode, PrayerLocationMode.city);
      expect(settings.city, 'Jakarta');
      expect(settings.method, 20);
      expect(settings.school, 0);
      expect(settings.isSet, isTrue);
      expect(SharedPreferencesService.hasPrayerCity(), isFalse);
    });

    test('pengguna lama tetap mode kota dengan kotanya', () async {
      SharedPreferences.setMockInitialValues({
        'prayer_city': 'Makassar',
        'prayer_country': 'Indonesia',
      });
      await SharedPreferencesService.init();
      final settings = PrayerSettingsStore.load();
      expect(settings.mode, PrayerLocationMode.city);
      expect(settings.city, 'Makassar');
      expect(settings.usesCoordinates, isFalse);
      expect(settings.method, 20);
    });

    test(
      'simpan: semua kunci salat.*, kota terakhir maks 5, revisi naik',
      () async {
        final before = PrayerSettingsStore.revision.value;
        for (final city in ['A', 'B', 'C', 'D', 'E', 'F', 'b']) {
          await PrayerSettingsStore.save(
            PrayerSettings(city: city, country: 'Indonesia', method: 3),
          );
        }
        expect(PrayerSettingsStore.revision.value, before + 7);
        expect(PrayerSettingsStore.recentCities().map((p) => p.$1), [
          'b',
          'F',
          'E',
          'D',
          'C',
        ]);
        await PrayerSettingsStore.save(
          PrayerSettings(
            mode: PrayerLocationMode.auto,
            coordinates: Coordinates.rounded(-6.21, 106.84),
            school: 1,
            tune: const [1, 0, 0, 0, -2],
          ),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('salat.lokasi.mode'), 'otomatis');
        expect(prefs.getString('salat.lokasi.koordinat'), '-6.2,106.85');
        expect(prefs.getInt('salat.metode'), 20);
        expect(prefs.getInt('salat.asar'), 1);
        expect(prefs.getString('salat.koreksi'), '1,0,0,0,-2');
        // Mode otomatis tidak menimpa kota yang tersimpan.
        expect(prefs.getString('prayer_city'), 'b');
        expect(PrayerSettingsStore.load().usesCoordinates, isTrue);
      },
    );

    test('kunci salat.* tidak ikut sinkron cloud', () {
      for (final path in [
        'lib/services/firebase_sync.dart',
        'lib/services/cloud_sync_service.dart',
      ]) {
        final source = File(path).readAsStringSync();
        for (final key in [
          'salat.',
          'getPrayerLocationMode',
          'getPrayerCoordinates',
          'getPrayerMethod',
          'getPrayerSchool',
          'getPrayerTune',
          'getRecentPrayerCities',
        ]) {
          expect(source, isNot(contains(key)), reason: '$path memuat $key');
        }
      }
    });
  });

  group('pembaruan lokasi otomatis saat aplikasi dibuka', () {
    final rescheduled = <PrayerSettings>[];
    final fetched = <PrayerSettings>[];

    Future<bool> run(FakePrayerLocator locator, {bool fail = false}) =>
        refreshPrayerLocationIfMoved(
          locator: locator,
          fetch: (settings) async {
            fetched.add(settings);
            if (fail) throw const SocketException('luring');
            return _day();
          },
          reschedule: (day, settings) async => rescheduled.add(settings),
        );

    setUp(() async {
      rescheduled.clear();
      fetched.clear();
      SharedPreferences.setMockInitialValues({
        'salat.lokasi.mode': 'otomatis',
        'salat.lokasi.koordinat': '-6.2,106.85',
      });
      await SharedPreferencesService.init();
    });

    test(
      'pindah > 25 km: setelan diperbarui & pengingat dijadwalkan ulang',
      () async {
        final moved = await run(FakePrayerLocator(last: (-6.914, 107.609)));
        expect(moved, isTrue);
        final here = Coordinates.rounded(-6.914, 107.609);
        expect(PrayerSettingsStore.load().coordinates, here);
        expect(rescheduled.single.coordinates, here);
      },
    );

    test('pindah dekat: tidak ada yang berubah', () async {
      expect(await run(FakePrayerLocator(last: (-6.3, 106.9))), isFalse);
      expect(fetched, isEmpty);
      expect(rescheduled, isEmpty);
    });

    test(
      'izin tidak ada: tidak meminta izin, tetap lokasi tersimpan',
      () async {
        final locator = FakePrayerLocator(
          access: LocationAccess.denied,
          last: (-6.914, 107.609),
        );
        expect(await run(locator), isFalse);
        expect(locator.requests, 0);
        expect(PrayerSettingsStore.load().coordinates!.storage, '-6.2,106.85');
      },
    );

    test('luring: lokasi lama tetap dipakai', () async {
      expect(
        await run(FakePrayerLocator(last: (-6.914, 107.609)), fail: true),
        isFalse,
      );
      expect(PrayerSettingsStore.load().coordinates!.storage, '-6.2,106.85');
      expect(rescheduled, isEmpty);
    });

    test('mode kota: tidak memeriksa lokasi sama sekali', () async {
      SharedPreferences.setMockInitialValues({'prayer_city': 'Bandung'});
      await SharedPreferencesService.init();
      expect(await run(FakePrayerLocator(last: (10, 10))), isFalse);
      expect(fetched, isEmpty);
    });
  });
}
