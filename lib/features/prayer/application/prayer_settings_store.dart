import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Membaca & menyimpan [PrayerSettings] di preferensi lokal (tidak ikut
/// sinkron cloud). Kunci: `salat.*` + `prayer_city`/`prayer_country` lama.
abstract final class PrayerSettingsStore {
  /// Bertambah setiap setelan disimpan; Beranda memuat ulang jadwal.
  static final revision = ValueNotifier<int>(0);

  static const recentLimit = 5;

  /// Setelan sekarang. Pengguna lama (tanpa `salat.lokasi.mode`) tetap
  /// mode kota dengan kotanya; yang belum pernah memilih memakai Jakarta.
  static PrayerSettings load() => PrayerSettings(
    mode: PrayerLocationMode.parse(
      SharedPreferencesService.getPrayerLocationMode(),
    ),
    city: SharedPreferencesService.getPrayerCity(),
    country: SharedPreferencesService.getPrayerCountry(),
    coordinates: Coordinates.parse(
      SharedPreferencesService.getPrayerCoordinates(),
    ),
    method: SharedPreferencesService.getPrayerMethod(),
    school: SharedPreferencesService.getPrayerSchool(),
    tune: PrayerSettings.parseTune(SharedPreferencesService.getPrayerTune()),
  );

  static Future<void> save(PrayerSettings settings) async {
    await SharedPreferencesService.setPrayerLocationMode(settings.mode.storage);
    final point = settings.coordinates;
    if (point != null) {
      await SharedPreferencesService.setPrayerCoordinates(point.storage);
    }
    if (settings.mode == PrayerLocationMode.city) {
      await SharedPreferencesService.setPrayerPlace(
        settings.city,
        settings.country,
      );
      await _remember(settings.city.trim(), settings.country.trim());
    }
    await SharedPreferencesService.setPrayerMethod(settings.method);
    await SharedPreferencesService.setPrayerSchool(settings.school);
    await SharedPreferencesService.setPrayerTune(settings.tuneStorage);
    revision.value++;
  }

  /// Kota yang terakhir dipakai, terbaru di depan.
  static List<(String, String)> recentCities() => [
    for (final raw in SharedPreferencesService.getRecentPrayerCities())
      if (raw.split('|') case [final city, final country]) (city, country),
  ];

  static Future<void> _remember(String city, String country) async {
    final key = '$city|$country';
    final places = [
      key,
      for (final raw in SharedPreferencesService.getRecentPrayerCities())
        if (raw.toLowerCase() != key.toLowerCase()) raw,
    ];
    await SharedPreferencesService.setRecentPrayerCities(
      places.take(recentLimit).toList(),
    );
  }
}
