import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

PrayerDay _day({String? timezone}) => PrayerDay(
  gregorianDate: DateTime(2026, 9, 22),
  hijriDate: '10 Rabi al-awwal 1448',
  hijriMonth: 'Rabi al-awwal',
  prayers: const {
    'Subuh': '04:32',
    'Dzuhur': '11:48',
    'Ashar': '15:13',
    'Maghrib': '17:54',
    'Isya': '19:07',
  },
  timezone: timezone,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('waktu salat ditafsirkan di zona kota, bukan zona HP', () {
    final jakarta = tz.getLocation('Asia/Jakarta');
    // Phone on Jakarta time, prayer city Makkah (UTC+3).
    final subuh = prayerInstant(
      _day(timezone: 'Asia/Riyadh'),
      'Subuh',
      jakarta,
    )!;
    expect(subuh.toUtc(), DateTime.utc(2026, 9, 22, 1, 32));
    // Which is 08:32 on the phone's Jakarta clock.
    final onPhone = tz.TZDateTime.from(subuh, jakarta);
    expect((onPhone.hour, onPhone.minute), (8, 32));
  });

  test('kota di zona yang sama dengan HP tidak bergeser', () {
    final jakarta = tz.getLocation('Asia/Jakarta');
    final subuh = prayerInstant(
      _day(timezone: 'Asia/Jakarta'),
      'Subuh',
      jakarta,
    )!;
    expect(subuh.toUtc(), DateTime.utc(2026, 9, 21, 21, 32));
  });

  test('tanpa zona atau zona tidak dikenal memakai zona cadangan', () {
    final jakarta = tz.getLocation('Asia/Jakarta');
    final expected = DateTime.utc(2026, 9, 21, 21, 32);
    expect(prayerInstant(_day(), 'Subuh', jakarta)!.toUtc(), expected);
    expect(
      prayerInstant(_day(timezone: 'Mars/Olympus'), 'Subuh', jakarta)!.toUtc(),
      expected,
    );
  });

  test('nama salat yang tidak ada menghasilkan null', () {
    expect(prayerInstant(_day(), 'Dhuha', tz.UTC), isNull);
  });

  group('label salat berikutnya', () {
    test('memakai zona kota: Subuh Makkah belum lewat saat 07:00 WIB', () {
      // 07:00 WIB = 00:00 UTC = 03:00 Makkah, before Subuh 04:32 Makkah.
      final now = DateTime.utc(2026, 9, 22, 0, 0);
      expect(_day(timezone: 'Asia/Riyadh').nextLabelAt(now), 'Subuh');
    });

    test('setelah Isya kota, label menjadi Subuh besok', () {
      // 19:30 Makkah = 16:30 UTC.
      final now = DateTime.utc(2026, 9, 22, 16, 30);
      expect(_day(timezone: 'Asia/Riyadh').nextLabelAt(now), 'Subuh besok');
    });

    test('di antara dua waktu memilih yang berikutnya', () {
      // 12:00 Makkah = 09:00 UTC, after Dzuhur 11:48.
      final now = DateTime.utc(2026, 9, 22, 9, 0);
      expect(_day(timezone: 'Asia/Riyadh').nextLabelAt(now), 'Ashar');
    });

    test('tanpa zona kota tetap memakai jam perangkat', () {
      expect(_day().nextLabelAt(DateTime(2026, 9, 22, 12)), 'Ashar');
    });
  });
}
