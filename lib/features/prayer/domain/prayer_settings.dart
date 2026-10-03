import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Lokasi & cara hitung waktu salat (docs/design/v6/screens/22-pengaturan-
/// salat.md). Fungsi murni: tidak membaca preferensi, jaringan, atau jam.

/// Cara menentukan tempat jadwal salat.
enum PrayerLocationMode {
  /// Kota + negara yang diketik (perilaku lama, bawaan).
  city('kota'),

  /// Koordinat perangkat yang dibulatkan.
  auto('otomatis');

  const PrayerLocationMode(this.storage);

  /// Nilai di preferensi `salat.lokasi.mode`.
  final String storage;

  static PrayerLocationMode parse(String? value) =>
      value == auto.storage ? auto : city;
}

/// Koordinat yang sudah dibulatkan ke kisi [step].
@immutable
class Coordinates {
  const Coordinates(this.latitude, this.longitude);

  /// Dibulatkan ke kisi [step] sebelum disimpan atau dikirim ke AlAdhan.
  factory Coordinates.rounded(double latitude, double longitude) =>
      Coordinates(_snap(latitude), _snap(longitude));

  final double latitude;
  final double longitude;

  /// Kisi 0,025° (≈ 2,8 km). Satu sel ≥ 3 km² sampai lintang ±67°, jadi
  /// sah disebut "lokasi perkiraan" menurut Data safety Google Play
  /// (approximate = area ≥ 3 km²). Kisi 2 desimal (≈ 1,2 km²) termasuk
  /// lokasi presisi. Keputusan pemilik 2026-10-03 (docs/decisions.md).
  /// Pengaruhnya ke jadwal salat kurang dari 5 detik.
  static const step = 0.025;

  static double _snap(double value) {
    final snapped = double.parse(
      ((value / step).round() * step).toStringAsFixed(3),
    );
    // -0.0 akan tertulis "-0" di preferensi & URL.
    return snapped == 0 ? 0 : snapped;
  }

  /// "-6.2,106.85" untuk preferensi `salat.lokasi.koordinat`.
  String get storage => '${_plain(latitude)},${_plain(longitude)}';

  /// "-6,2, 106,85" untuk layar (desimal koma).
  String get display =>
      '${_plain(latitude).replaceAll('.', ',')}, '
      '${_plain(longitude).replaceAll('.', ',')}';

  static String _plain(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  static Coordinates? parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final latitude = double.tryParse(parts.first.trim());
    final longitude = double.tryParse(parts.last.trim());
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return Coordinates(latitude, longitude);
  }

  /// Jarak lingkaran besar (haversine), dalam km.
  double distanceKm(Coordinates other) {
    const earthKm = 6371.0;
    double rad(double degree) => degree * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLon = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * earthKm * math.asin(math.sqrt(a));
  }

  @override
  bool operator ==(Object other) =>
      other is Coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Coordinates($storage)';
}

/// Satu metode hitung AlAdhan.
@immutable
class PrayerMethod {
  const PrayerMethod(this.id, this.name, this.label);

  /// ID resmi AlAdhan.
  final int id;

  /// Nama resmi AlAdhan.
  final String name;

  /// Nama di layar.
  final String label;
}

/// Metode yang bisa dipilih, Kemenag RI di atas sebagai bawaan.
///
/// ID & nama diambil dari daftar resmi AlAdhan, bukan dari ingatan:
/// `GET https://api.aladhan.com/v1/methods` (dicek 2026-10-03), yang sama
/// dengan https://aladhan.com/calculation-methods. Hasil saat dicek:
/// MWL=3, ISNA=2, EGYPT=5, MAKKAH=4, SINGAPORE=11, JAKIM=17, KEMENAG=20.
const prayerMethods = [
  PrayerMethod(20, 'Kementerian Agama Republik Indonesia', 'Kemenag RI'),
  PrayerMethod(3, 'Muslim World League', 'Muslim World League'),
  PrayerMethod(4, 'Umm Al-Qura University, Makkah', 'Umm al-Qura, Makkah'),
  PrayerMethod(5, 'Egyptian General Authority of Survey', 'Otoritas Mesir'),
  PrayerMethod(17, 'Jabatan Kemajuan Islam Malaysia (JAKIM)', 'JAKIM Malaysia'),
  PrayerMethod(11, 'Majlis Ugama Islam Singapura, Singapore', 'MUIS Singapura'),
  PrayerMethod(2, 'Islamic Society of North America (ISNA)', 'ISNA'),
];

/// Metode dengan [id], atau Kemenag RI bila tidak dikenal.
PrayerMethod prayerMethodOf(int id) => prayerMethods.firstWhere(
  (method) => method.id == id,
  orElse: () => prayerMethods.first,
);

/// Setelan waktu salat yang dipakai untuk satu permintaan jadwal.
@immutable
class PrayerSettings {
  const PrayerSettings({
    this.mode = PrayerLocationMode.city,
    this.city = defaultCity,
    this.country = defaultCountry,
    this.coordinates,
    this.method = defaultMethod,
    this.school = 0,
    this.tune = noTune,
  });

  /// Kota bawaan bila pengguna belum pernah memilih (keputusan pemilik
  /// 2026-10-03: tetap Jakarta).
  static const defaultCity = 'Jakarta';
  static const defaultCountry = 'Indonesia';

  /// Kemenag RI (AlAdhan 20).
  static const defaultMethod = 20;

  /// Koreksi menit Subuh, Dzuhur, Ashar, Maghrib, Isya.
  static const noTune = [0, 0, 0, 0, 0];
  static const tuneLimit = 10;

  final PrayerLocationMode mode;
  final String city;
  final String country;

  /// Koordinat yang sudah dibulatkan; hanya dipakai di mode otomatis.
  final Coordinates? coordinates;

  /// ID metode AlAdhan.
  final int method;

  /// Mazhab Asar untuk AlAdhan `school`: 0 = Standar (Syafi'i, Maliki,
  /// Hanbali), 1 = Hanafi. Dicek: `meta.school` STANDARD/HANAFI.
  final int school;

  /// Koreksi menit per waktu, urutan [noTune].
  final List<int> tune;

  /// Mode otomatis dengan koordinat; tanpa koordinat jatuh ke kota.
  bool get usesCoordinates =>
      mode == PrayerLocationMode.auto && coordinates != null;

  /// Ada tempat yang bisa dimintakan jadwal.
  bool get isSet =>
      usesCoordinates || (city.trim().isNotEmpty && country.trim().isNotEmpty);

  bool get hasTune => tune.any((minutes) => minutes != 0);

  /// Parameter AlAdhan `tune`: 9 nilai berurutan Imsak, Fajr, Sunrise,
  /// Dhuhr, Asr, Maghrib, Sunset, Isha, Midnight. Dicek 2026-10-03 lewat
  /// `meta.offset` respons `tune=1,2,…,9`. Hanya 5 waktu salat yang diisi.
  String get tuneParam {
    final t = [for (var i = 0; i < 5; i++) i < tune.length ? tune[i] : 0];
    return [0, t[0], 0, t[1], t[2], t[3], 0, t[4], 0].join(',');
  }

  /// Tempat saja, untuk daftar & pembanding.
  String get placeKey => usesCoordinates
      ? 'geo:${coordinates!.storage}'
      : 'kota:${city.trim().toLowerCase()}|${country.trim().toLowerCase()}';

  /// Kunci simpanan jadwal: tempat + metode + Asar + koreksi, supaya jadwal
  /// lama tidak dipakai setelah setelan berubah.
  String get cacheKey => '$placeKey|m$method|s$school|t${tune.join(',')}';

  /// Permintaan AlAdhan untuk tanggal [day].
  ///
  /// Endpoint (dicek 2026-10-03 dengan permintaan nyata):
  /// `/v1/timings/{dd-MM-yyyy}?latitude&longitude&method&school&tune` dan
  /// `/v1/timingsByCity/{dd-MM-yyyy}?city&country&method&school&tune`.
  /// Keduanya mengembalikan `data.meta.timezone`.
  Uri uriFor(DateTime day) {
    final date =
        '${day.day.toString().padLeft(2, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-${day.year}';
    final common = {
      'method': '$method',
      'school': '$school',
      if (hasTune) 'tune': tuneParam,
    };
    final point = coordinates;
    if (usesCoordinates && point != null) {
      final parts = point.storage.split(',');
      return Uri.https('api.aladhan.com', '/v1/timings/$date', {
        'latitude': parts.first,
        'longitude': parts.last,
        ...common,
      });
    }
    return Uri.https('api.aladhan.com', '/v1/timingsByCity/$date', {
      'city': city,
      'country': country,
      ...common,
    });
  }

  PrayerSettings copyWith({
    PrayerLocationMode? mode,
    String? city,
    String? country,
    Coordinates? coordinates,
    int? method,
    int? school,
    List<int>? tune,
  }) => PrayerSettings(
    mode: mode ?? this.mode,
    city: city ?? this.city,
    country: country ?? this.country,
    coordinates: coordinates ?? this.coordinates,
    method: method ?? this.method,
    school: school ?? this.school,
    tune: tune ?? this.tune,
  );

  /// "0,0,0,0,0" untuk preferensi `salat.koreksi`.
  String get tuneStorage => tune.join(',');

  /// Koreksi dari preferensi; nilai rusak = 0, dibatasi ±[tuneLimit].
  static List<int> parseTune(String? raw) {
    final parts = raw?.split(',') ?? const <String>[];
    return [
      for (var i = 0; i < 5; i++)
        i < parts.length
            ? (int.tryParse(parts[i].trim()) ?? 0)
                  .clamp(-tuneLimit, tuneLimit)
                  .toInt()
            : 0,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerSettings && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() => 'PrayerSettings($cacheKey)';
}
