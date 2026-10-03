import 'package:geolocator/geolocator.dart';

/// Keadaan izin & layanan lokasi untuk waktu salat.
enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// Yang dibutuhkan waktu salat dari lokasi perangkat. Dipisah dari
/// Geolocator supaya lembar & pembaruan otomatis bisa dites.
abstract class PrayerLocator {
  /// Keadaan sekarang tanpa meminta izin.
  Future<LocationAccess> check();

  /// Meminta izin (dialog sistem) bila belum diputuskan.
  Future<LocationAccess> request();

  /// Posisi sekarang, akurasi rendah; null bila gagal.
  Future<(double, double)?> current();

  /// Posisi terakhir yang diketahui sistem; null bila tidak ada.
  Future<(double, double)?> lastKnown();

  /// Pengaturan aplikasi di HP (izin ditolak permanen).
  Future<void> openSettings();
}

/// [PrayerLocator] di atas Geolocator (paket yang sudah dipakai kiblat).
class GeolocatorPrayerLocator implements PrayerLocator {
  const GeolocatorPrayerLocator();

  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };

  @override
  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    final now = await check();
    if (now != LocationAccess.denied) return now;
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<(double, double)?> current() async {
    try {
      // Akurasi rendah cukup: koordinat tetap dibulatkan ke kisi ±3 km.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (position.latitude, position.longitude);
    } on Object {
      return null;
    }
  }

  @override
  Future<(double, double)?> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : (position.latitude, position.longitude);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
