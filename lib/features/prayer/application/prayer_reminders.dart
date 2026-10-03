import 'package:quran_app_2025/features/prayer/application/prayer_locator.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_settings_store.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Jadwal salat untuk [PrayerSettings] (dioper supaya bisa dites).
typedef PrayerFetcher = Future<PrayerDay> Function(PrayerSettings settings);

/// Menjadwalkan ulang pengingat setelah setelan waktu salat berubah.
typedef PrayerRescheduler =
    Future<void> Function(PrayerDay day, PrayerSettings settings);

Future<PrayerDay> fetchPrayerDay(PrayerSettings settings) =>
    PrayerService.fetch(settings: settings);

/// Menjadwalkan ulang pengingat yang tersimpan untuk [settings] — logika
/// ganti kota di layar Salat, dipakai juga oleh lembar Waktu salat dan
/// pembaruan lokasi otomatis. Tidak meminta izin notifikasi: pengingat
/// tersimpan berarti izinnya sudah diberikan saat diaktifkan.
Future<void> reschedulePrayerReminders(
  PrayerDay day,
  PrayerSettings settings,
) async {
  final prayers = SharedPreferencesService.getPrayerReminders();
  final quran = SharedPreferencesService.getQuranReminderMinutes();
  final session = SharedPreferencesService.getSessionReminderMinutes();
  if (prayers.isEmpty && quran == null && session == null) return;
  await ReminderService.instance.schedule(
    day: day,
    prayerNames: prayers,
    quranReminderMinutes: quran,
    sessionReminderMinutes: session,
    settings: settings,
  );
}

/// Pindah lebih jauh dari ini dianggap ganti tempat (22-pengaturan-salat §A).
const prayerMovedKm = 25.0;

/// Dipanggil saat aplikasi dibuka. Mode Otomatis + izin masih ada: posisi
/// terakhir dibandingkan dengan yang tersimpan; bila pindah > 25 km, jadwal
/// diambil ulang, setelan disimpan, dan pengingat dijadwalkan ulang tanpa
/// bertanya. Tidak pernah meminta izin. True bila ada perubahan.
Future<bool> refreshPrayerLocationIfMoved({
  PrayerLocator locator = const GeolocatorPrayerLocator(),
  PrayerFetcher fetch = fetchPrayerDay,
  PrayerRescheduler reschedule = reschedulePrayerReminders,
}) async {
  final settings = PrayerSettingsStore.load();
  final saved = settings.coordinates;
  if (settings.mode != PrayerLocationMode.auto || saved == null) return false;
  if (await locator.check() != LocationAccess.granted) return false;
  final raw = await locator.lastKnown();
  if (raw == null) return false;
  final here = Coordinates.rounded(raw.$1, raw.$2);
  if (here.distanceKm(saved) <= prayerMovedKm) return false;
  final next = settings.copyWith(coordinates: here);
  final PrayerDay day;
  try {
    day = await fetch(next);
  } on Object {
    // Luring: tetap pakai lokasi tersimpan, coba lagi saat dibuka berikutnya.
    return false;
  }
  await PrayerSettingsStore.save(next);
  await reschedule(day, next);
  return true;
}
