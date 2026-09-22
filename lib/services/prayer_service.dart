import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

class PrayerDay {
  const PrayerDay({
    required this.gregorianDate,
    required this.hijriDate,
    required this.hijriMonth,
    required this.prayers,
    this.timezone,
  });

  final DateTime gregorianDate;

  /// IANA zone of the chosen city (AlAdhan `meta.timezone`). Prayer times
  /// are wall-clock times in this zone, which may differ from the phone's.
  final String? timezone;
  final String hijriDate;
  final String hijriMonth;
  final Map<String, String> prayers;

  String get nextLabel => nextLabelAt(DateTime.now());

  /// Next prayer after [now]. When the city's zone is known, compares real
  /// instants so a city in another zone is labelled correctly; otherwise
  /// compares against the phone's wall clock as before.
  String nextLabelAt(DateTime now) {
    final zone = _location();
    for (final entry in prayers.entries) {
      if (zone != null) {
        final at = prayerInstant(this, entry.key, zone);
        if (at != null && at.isAfter(now)) return entry.key;
      } else {
        final time = _toDateTime(entry.value, now);
        if (time.isAfter(now)) return entry.key;
      }
    }
    return 'Subuh besok';
  }

  tz.Location? _location() {
    final name = timezone;
    if (name == null) return null;
    try {
      return tz.getLocation(name);
    } on Object {
      return null;
    }
  }

  DateTime? timeFor(String label) {
    final value = prayers[label];
    return value == null ? null : _toDateTime(value, gregorianDate);
  }

  static DateTime _toDateTime(String value, DateTime day) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) throw FormatException('Waktu salat tidak valid: $value');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(match[1]!),
      int.parse(match[2]!),
    );
  }
}

class PrayerService {
  static const prayerNames = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];

  /// Prayer times for [date], or for *today in the city* when omitted. The
  /// phone and the city can be on different calendar days (e.g. just after
  /// midnight in Jakarta while Honolulu is still on the previous day), so an
  /// omitted date is re-resolved in the city's zone.
  static Future<PrayerDay> fetch({
    required String city,
    required String country,
    DateTime? date,
  }) async {
    final day = await _fetchDay(city: city, country: country, date: date);
    if (date != null) return day;
    final cityToday = cityDate(day.timezone, DateTime.now());
    if (cityToday == null || cityToday == day.gregorianDate) return day;
    return _fetchDay(city: city, country: country, date: cityToday);
  }

  /// Calendar date at [now] in [zone], or null if the zone is unknown.
  static DateTime? cityDate(String? zone, DateTime now) {
    if (zone == null) return null;
    try {
      final local = tz.TZDateTime.from(now, tz.getLocation(zone));
      return DateTime(local.year, local.month, local.day);
    } on Object {
      return null;
    }
  }

  static Future<PrayerDay> _fetchDay({
    required String city,
    required String country,
    DateTime? date,
  }) async {
    final requested = date ?? DateTime.now();
    final day = DateTime(requested.year, requested.month, requested.day);
    final formattedDate =
        '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/timingsByCity/$formattedDate',
      {'city': city, 'country': country, 'method': '20'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Jadwal salat belum dapat dimuat.');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>?;
    final timings = data?['timings'] as Map<String, dynamic>?;
    final hijri =
        (data?['date'] as Map<String, dynamic>?)?['hijri']
            as Map<String, dynamic>?;
    if (timings == null || hijri == null) {
      throw const FormatException('Respons jadwal tidak lengkap.');
    }
    final sourceKeys = {
      'Subuh': 'Fajr',
      'Dzuhur': 'Dhuhr',
      'Ashar': 'Asr',
      'Maghrib': 'Maghrib',
      'Isya': 'Isha',
    };
    final prayers = <String, String>{
      for (final entry in sourceKeys.entries)
        entry.key: (timings[entry.value] as String? ?? '').split(' ').first,
    };
    if (prayers.values.any(
      (value) => !RegExp(r'^\d{1,2}:\d{2}').hasMatch(value),
    )) {
      throw const FormatException('Waktu salat tidak valid.');
    }
    final month = hijri['month'] as Map<String, dynamic>?;
    final meta = data?['meta'] as Map<String, dynamic>?;
    return PrayerDay(
      timezone: meta?['timezone'] as String?,
      gregorianDate: day,
      hijriDate: '${hijri['day']} ${month?['en'] ?? ''} ${hijri['year']}',
      hijriMonth: month?['en'] as String? ?? '',
      prayers: prayers,
    );
  }
}

/// The moment [prayer] happens: its wall-clock time interpreted in the
/// city's own zone ([PrayerDay.timezone]), not the phone's. A prayer city in
/// another zone would otherwise be reminded hours early or late. Falls back
/// to [fallback] when the city zone is missing or unknown.
tz.TZDateTime? prayerInstant(
  PrayerDay day,
  String prayer,
  tz.Location fallback,
) {
  final time = day.timeFor(prayer);
  if (time == null) return null;
  var location = fallback;
  final zone = day.timezone;
  if (zone != null) {
    try {
      location = tz.getLocation(zone);
    } on Object {
      location = fallback;
    }
  }
  return tz.TZDateTime(
    location,
    time.year,
    time.month,
    time.day,
    time.hour,
    time.minute,
  );
}
