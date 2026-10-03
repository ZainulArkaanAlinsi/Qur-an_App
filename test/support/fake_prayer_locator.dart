import 'package:quran_app_2025/features/prayer/application/prayer_locator.dart';

/// Lokasi palsu untuk lembar Waktu salat dan pembaruan otomatis.
class FakePrayerLocator implements PrayerLocator {
  FakePrayerLocator({
    this.access = LocationAccess.granted,
    this.afterRequest,
    this.position,
    this.last,
  });

  /// Keadaan sebelum diminta.
  LocationAccess access;

  /// Keadaan setelah dialog izin; bawaan sama dengan [access].
  LocationAccess? afterRequest;
  (double, double)? position;
  (double, double)? last;

  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> check() async => access;

  @override
  Future<LocationAccess> request() async {
    requests++;
    access = afterRequest ?? access;
    return access;
  }

  @override
  Future<(double, double)?> current() async => position;

  @override
  Future<(double, double)?> lastKnown() async => last;

  @override
  Future<void> openSettings() async => settingsOpened++;
}
