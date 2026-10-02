import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/home/domain/prayer_horizon.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// docs/DATA.md §6: horizon salat.
PrayerDay _day({
  DateTime? date,
  String? timezone,
  Map<String, String>? prayers,
}) => PrayerDay(
  gregorianDate: date ?? DateTime(2026, 10, 2),
  hijriDate: '20-04-1448',
  hijriMonth: 'Rabiulakhir',
  timezone: timezone,
  prayers:
      prayers ??
      const {
        'Subuh': '04:22',
        'Dzuhur': '11:42',
        'Ashar': '14:50',
        'Maghrib': '17:49',
        'Isya': '18:58',
      },
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('sebelum Subuh: titik sekarang di awal, berikutnya Subuh', () {
    final model = buildHorizon(_day(), DateTime(2026, 10, 2, 3, 0))!;
    expect(model.nodes.map((n) => n.label), PrayerService.prayerNames);
    expect(model.nextIndex, 0);
    expect(model.isTomorrow, isFalse);
    expect(model.nowPosition, 0);
    expect(model.untilNext, const Duration(hours: 1, minutes: 22));
  });

  test('tepat di jam Dzuhur: Dzuhur sudah masuk, berikutnya Ashar', () {
    final model = buildHorizon(_day(), DateTime(2026, 10, 2, 11, 42))!;
    expect(model.nextIndex, 2);
    expect(model.nowPosition, closeTo(1 / 4, 1e-9));
  });

  test('di tengah Ashar–Maghrib: proporsional di antara keduanya', () {
    // Ashar 14:50, Maghrib 17:49 → tengahnya 16:19:30.
    final model = buildHorizon(_day(), DateTime(2026, 10, 2, 16, 19, 30))!;
    expect(model.nextIndex, 3);
    expect(model.nowPosition, closeTo((2 + .5) / 4, 1e-6));
    expect(horizonCountdown(model.untilNext!), '1 j 29 m lagi');
  });

  test('setelah Isya: Subuh besok, titik di ujung kanan', () {
    final model = buildHorizon(_day(), DateTime(2026, 10, 2, 21))!;
    expect(model.isTomorrow, isTrue);
    expect(model.nextIndex, 0);
    expect(model.nowPosition, 1);
    // Jadwal besok belum ada: tanpa jam, bukan jam karangan.
    expect(model.untilNext, isNull);
    expect(model.tomorrowTime, isNull);

    final tomorrow = _day(
      date: DateTime(2026, 10, 3),
      prayers: const {
        'Subuh': '04:21',
        'Dzuhur': '11:42',
        'Ashar': '14:50',
        'Maghrib': '17:49',
        'Isya': '18:58',
      },
    );
    final withTomorrow = buildHorizon(
      _day(),
      DateTime(2026, 10, 2, 21),
      tomorrow: tomorrow,
    )!;
    expect(withTomorrow.tomorrowTime, '04:21');
    expect(withTomorrow.untilNext, const Duration(hours: 7, minutes: 21));
  });

  test('zona kota ≠ zona HP: dibandingkan sebagai instan di zona kota', () {
    // Jayapura (WIT, UTC+9). 02:00 UTC = 11:00 WIT → berikutnya Dzuhur 11:42,
    // berapa pun zona HP tempat tes berjalan.
    final model = buildHorizon(
      _day(timezone: 'Asia/Jayapura'),
      DateTime.utc(2026, 10, 2, 2),
    )!;
    expect(model.nextIndex, 1);
    expect(model.untilNext, const Duration(minutes: 42));
    expect(horizonCountdown(model.untilNext!), '42 m lagi');
  });

  test('data tidak lengkap → null', () {
    final missing = _day(
      prayers: const {
        'Subuh': '04:22',
        'Dzuhur': '11:42',
        'Ashar': '14:50',
        'Isya': '18:58',
      },
    );
    expect(buildHorizon(missing, DateTime(2026, 10, 2, 9)), isNull);
  });

  test('hitung mundur: di bawah satu jam hanya menit', () {
    expect(horizonCountdown(const Duration(minutes: 59)), '59 m lagi');
    expect(
      horizonCountdown(const Duration(hours: 1, minutes: 7)),
      '1 j 7 m lagi',
    );
  });
}
