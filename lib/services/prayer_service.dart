import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:timezone/timezone.dart' as tz;

class PrayerDay {
  const PrayerDay({
    required this.gregorianDate,
    required this.hijriDate,
    required this.hijriMonth,
    required this.prayers,
    this.timezone,
    this.sunrise,
    this.sunset,
    this.hijriDay,
    this.hijriMonthNumber,
    this.hijriYear,
    this.fromCache = false,
  });

  factory PrayerDay.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) => PrayerDay(
    gregorianDate: DateTime.parse(json['date'] as String),
    timezone: json['timezone'] as String?,
    hijriDate: json['hijriDate'] as String? ?? '',
    hijriMonth: json['hijriMonth'] as String? ?? '',
    prayers: (json['prayers'] as Map).cast<String, String>(),
    sunrise: json['sunrise'] as String?,
    sunset: json['sunset'] as String?,
    hijriDay: json['hijriDay'] as int?,
    hijriMonthNumber: json['hijriMonthNumber'] as int?,
    hijriYear: json['hijriYear'] as int?,
    fromCache: fromCache,
  );

  Map<String, dynamic> toJson() => {
    'date': dateKey(gregorianDate),
    'timezone': timezone,
    'hijriDate': hijriDate,
    'hijriMonth': hijriMonth,
    'prayers': prayers,
    'sunrise': sunrise,
    'sunset': sunset,
    'hijriDay': hijriDay,
    'hijriMonthNumber': hijriMonthNumber,
    'hijriYear': hijriYear,
  };

  /// "2026-09-24".
  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Diambil dari simpanan di perangkat karena AlAdhan tidak terjangkau.
  /// Hanya jadwal untuk tanggal yang sama yang boleh dipakai.
  final bool fromCache;

  final DateTime gregorianDate;

  /// IANA zone of the chosen city (AlAdhan `meta.timezone`). Prayer times
  /// are wall-clock times in this zone, which may differ from the phone's.
  final String? timezone;
  final String hijriDate;
  final String hijriMonth;
  final Map<String, String> prayers;

  /// Tanggal Hijriah dalam angka dari AlAdhan, supaya nama bulannya bisa
  /// ditulis dalam bahasa Indonesia. Null bila responsnya tidak memuatnya.
  final int? hijriDay;
  final int? hijriMonthNumber;
  final int? hijriYear;

  /// Nama bulan Hijriah baku bahasa Indonesia (KBBI), Muharram = 1.
  static const hijriMonthsId = [
    'Muharram',
    'Safar',
    'Rabiulawal',
    'Rabiulakhir',
    'Jumadilawal',
    'Jumadilakhir',
    'Rajab',
    'Syakban',
    'Ramadan',
    'Syawal',
    'Zulkaidah',
    'Zulhijah',
  ];

  /// "13 Rabiulakhir 1448 H". Bulan hanya ditulis sekali (dulu tampil dobel:
  /// "…1448 Rabī' al-t…"). Kalau angka bulannya tidak ada, pakai teks asli.
  String get hijriIndonesian {
    final month = hijriMonthNumber;
    if (hijriDay == null ||
        hijriYear == null ||
        month == null ||
        month < 1 ||
        month > 12) {
      return hijriDate;
    }
    return '$hijriDay ${hijriMonthsId[month - 1]} $hijriYear H';
  }

  /// Terbit dan terbenam menurut AlAdhan, dipakai sebagai keterangan di kartu
  /// salat berikutnya. Keduanya bisa null: kalau responsnya tidak memuatnya,
  /// keterangan itu disembunyikan, bukan dikarang.
  final String? sunrise;
  final String? sunset;

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

  /// Metode kalkulasi AlAdhan yang dipakai. Nomor dan namanya mengikuti
  /// daftar resmi AlAdhan (aladhan.com/calculation-methods); ditampilkan di
  /// layar salat supaya pengguna tahu jadwalnya dihitung dengan cara apa.
  static const methodId = 20;
  static const methodName = 'Kementerian Agama Republik Indonesia';

  /// Prayer times for [date], or for *today in the city* when omitted. The
  /// phone and the city can be on different calendar days (e.g. just after
  /// midnight in Jakarta while Honolulu is still on the previous day), so an
  /// omitted date is re-resolved in the city's zone.
  ///
  /// Every successful day is kept on the device. When AlAdhan cannot be
  /// reached, a kept schedule is returned only if it is for the very same
  /// date ([PrayerDay.fromCache] set); yesterday's times are never shown as
  /// today's.
  static Future<PrayerDay> fetch({
    required String city,
    required String country,
    DateTime? date,
    http.Client? client,
    DateTime Function() clock = DateTime.now,
  }) async {
    try {
      var day = await _fetchDay(
        city: city,
        country: country,
        date: date,
        client: client,
      );
      if (date == null) {
        final cityToday = cityDate(day.timezone, clock());
        if (cityToday != null && cityToday != day.gregorianDate) {
          day = await _fetchDay(
            city: city,
            country: country,
            date: cityToday,
            client: client,
          );
        }
      }
      await _remember(city, country, day);
      return day;
    } on Object {
      final kept = _recall(city, country, date, clock());
      if (kept != null) return kept;
      rethrow;
    }
  }

  /// Nama metode singkat untuk baris keterangan.
  static const methodShort = 'Kemenag RI';

  static const _keptDays = 6;

  static String _placeKey(String city, String country) =>
      '${city.trim().toLowerCase()}|${country.trim().toLowerCase()}';

  static Map<String, dynamic> _kept() {
    final raw = SharedPreferencesService.getPrayerCache();
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on Object {
      return {};
    }
  }

  static Future<void> _remember(
    String city,
    String country,
    PrayerDay day,
  ) async {
    final kept = _kept();
    kept['${_placeKey(city, country)}|${PrayerDay.dateKey(day.gregorianDate)}'] =
        day.toJson();
    // Hanya beberapa hari terakhir yang disimpan.
    final keys = kept.keys.toList()
      ..sort((a, b) => a.split('|').last.compareTo(b.split('|').last));
    for (final key in keys.take(math.max(0, keys.length - _keptDays))) {
      kept.remove(key);
    }
    await SharedPreferencesService.setPrayerCache(jsonEncode(kept));
  }

  static PrayerDay? _recall(
    String city,
    String country,
    DateTime? date,
    DateTime now,
  ) {
    final place = _placeKey(city, country);
    for (final entry in _kept().entries) {
      if (!entry.key.startsWith('$place|')) continue;
      final PrayerDay day;
      try {
        day = PrayerDay.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
          fromCache: true,
        );
      } on Object {
        continue;
      }
      final wanted =
          date ??
          cityDate(day.timezone, now) ??
          DateTime(now.year, now.month, now.day);
      final target = DateTime(wanted.year, wanted.month, wanted.day);
      if (day.gregorianDate == target) return day;
    }
    return null;
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
    http.Client? client,
  }) async {
    final requested = date ?? DateTime.now();
    final day = DateTime(requested.year, requested.month, requested.day);
    final formattedDate =
        '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/timingsByCity/$formattedDate',
      {'city': city, 'country': country, 'method': '$methodId'},
    );
    final response = await (client?.get(uri) ?? http.get(uri)).timeout(
      const Duration(seconds: 12),
    );
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
    // Terbit/terbenam hanya pelengkap tampilan, jadi format yang tidak
    // dikenali diperlakukan sebagai "tidak dilaporkan".
    String? optionalTime(String key) {
      final value = (timings[key] as String?)?.split(' ').first;
      return value != null && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)
          ? value
          : null;
    }

    return PrayerDay(
      timezone: meta?['timezone'] as String?,
      sunrise: optionalTime('Sunrise'),
      sunset: optionalTime('Sunset'),
      gregorianDate: day,
      hijriDate: '${hijri['day']} ${month?['en'] ?? ''} ${hijri['year']}',
      hijriMonth: month?['en'] as String? ?? '',
      hijriDay: int.tryParse('${hijri['day']}'),
      hijriMonthNumber: int.tryParse('${month?['number']}'),
      hijriYear: int.tryParse('${hijri['year']}'),
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
