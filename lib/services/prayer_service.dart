import 'dart:convert';

import 'package:http/http.dart' as http;

class PrayerDay {
  const PrayerDay({
    required this.gregorianDate,
    required this.hijriDate,
    required this.hijriMonth,
    required this.prayers,
  });

  final DateTime gregorianDate;
  final String hijriDate;
  final String hijriMonth;
  final Map<String, String> prayers;

  String get nextLabel {
    final now = DateTime.now();
    for (final entry in prayers.entries) {
      final time = _toDateTime(entry.value, now);
      if (time.isAfter(now)) return entry.key;
    }
    return 'Subuh besok';
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

  static Future<PrayerDay> fetch({
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
    if (response.statusCode != 200)
      throw Exception('Jadwal salat belum dapat dimuat.');
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>?;
    final timings = data?['timings'] as Map<String, dynamic>?;
    final hijri =
        (data?['date'] as Map<String, dynamic>?)?['hijri']
            as Map<String, dynamic>?;
    if (timings == null || hijri == null)
      throw const FormatException('Respons jadwal tidak lengkap.');
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
    return PrayerDay(
      gregorianDate: day,
      hijriDate: '${hijri['day']} ${month?['en'] ?? ''} ${hijri['year']}',
      hijriMonth: month?['en'] as String? ?? '',
      prayers: prayers,
    );
  }
}
