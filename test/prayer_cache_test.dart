import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respons AlAdhan `timingsByCity` secukupnya.
http.Response _aladhan() => http.Response(
  jsonEncode({
    'data': {
      'timings': {
        'Fajr': '04:24',
        'Sunrise': '05:42',
        'Dhuhr': '11:45',
        'Asr': '14:54',
        'Sunset': '17:48',
        'Maghrib': '17:48',
        'Isha': '18:57',
      },
      'date': {
        'hijri': {
          'day': '12',
          'year': '1448',
          'month': {'number': 4, 'en': 'Rabi al-thani'},
        },
      },
      'meta': <String, dynamic>{},
    },
  }),
  200,
);

void main() {
  final day = DateTime(2026, 9, 24);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  Future<PrayerDay> online(DateTime date) => PrayerService.fetch(
    city: 'Jakarta',
    country: 'Indonesia',
    date: date,
    client: MockClient((_) async => _aladhan()),
  );

  MockClient offline() =>
      MockClient((_) async => throw const SocketException('luring'));

  test('memakai method=20 dan menyimpan jadwal yang berhasil', () async {
    Uri? asked;
    final result = await PrayerService.fetch(
      city: 'Jakarta',
      country: 'Indonesia',
      date: day,
      client: MockClient((request) async {
        asked = request.url;
        return _aladhan();
      }),
    );
    expect(asked!.queryParameters['method'], '20');
    expect(result.fromCache, isFalse);
    expect(SharedPreferencesService.getPrayerCache(), contains('2026-09-24'));
  });

  test('luring: jadwal tersimpan untuk tanggal yang sama dipakai', () async {
    await online(day);
    final kept = await PrayerService.fetch(
      city: ' jakarta ',
      country: 'Indonesia',
      date: day,
      client: offline(),
    );
    expect(kept.fromCache, isTrue);
    expect(kept.prayers['Maghrib'], '17:48');
    expect(kept.sunrise, '05:42');
  });

  test('luring: jadwal kemarin tidak pernah dipakai untuk hari ini', () async {
    await online(day);
    await expectLater(
      PrayerService.fetch(
        city: 'Jakarta',
        country: 'Indonesia',
        date: day.add(const Duration(days: 1)),
        client: offline(),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('luring: kota lain tidak memakai simpanan kota ini', () async {
    await online(day);
    await expectLater(
      PrayerService.fetch(
        city: 'Bandung',
        country: 'Indonesia',
        date: day,
        client: offline(),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('tanpa tanggal memakai tanggal hari ini menurut jam', () async {
    await online(day);
    final kept = await PrayerService.fetch(
      city: 'Jakarta',
      country: 'Indonesia',
      clock: () => DateTime(2026, 9, 24, 21),
      client: offline(),
    );
    expect(kept.gregorianDate, day);
  });

  test('simpanan dibatasi beberapa hari terakhir', () async {
    for (var i = 0; i < 10; i++) {
      await online(day.add(Duration(days: i)));
    }
    final kept = jsonDecode(SharedPreferencesService.getPrayerCache()!) as Map;
    expect(kept, hasLength(6));
    expect(kept.keys.any((k) => '$k'.endsWith('2026-09-24')), isFalse);
  });
}
