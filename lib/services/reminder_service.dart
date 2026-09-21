import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:quran_app_2025/services/prayer_service.dart';

class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_quran'),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  }

  Future<void> schedule({
    required PrayerDay day,
    required Set<String> prayerNames,
    int? quranReminderMinutes,
    required String city,
    required String country,
  }) async {
    await initialize();
    await _plugin.cancelAll();
    final dates = List.generate(
      14,
      (offset) => DateTime(
        day.gregorianDate.year,
        day.gregorianDate.month,
        day.gregorianDate.day + offset,
      ),
    );
    final fetched = await Future.wait(
      dates.map((date) async {
        if (date == day.gregorianDate) return day;
        try {
          return await PrayerService.fetch(
            city: city,
            country: country,
            date: date,
          );
        } catch (_) {
          return null;
        }
      }),
    );
    final now = tz.TZDateTime.now(tz.local);
    for (var dayOffset = 0; dayOffset < fetched.length; dayOffset++) {
      final scheduledDay = fetched[dayOffset];
      if (scheduledDay == null) continue;
      for (
        var prayerOffset = 0;
        prayerOffset < PrayerService.prayerNames.length;
        prayerOffset++
      ) {
        final prayer = PrayerService.prayerNames[prayerOffset];
        if (!prayerNames.contains(prayer)) continue;
        final time = scheduledDay.timeFor(prayer);
        if (time == null) continue;
        final scheduled = tz.TZDateTime.from(time, tz.local);
        if (!scheduled.isAfter(now)) continue;
        await _schedule(
          1000 + dayOffset * 10 + prayerOffset,
          scheduled,
          'Waktu $prayer',
          'Sudah masuk waktu $prayer.',
        );
      }
    }
    if (quranReminderMinutes != null) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        quranReminderMinutes ~/ 60,
        quranReminderMinutes % 60,
      );
      if (!scheduled.isAfter(now))
        scheduled = scheduled.add(const Duration(days: 1));
      await _scheduleDaily(
        200,
        scheduled,
        'Waktu tilawah',
        'Luangkan beberapa menit untuk membaca Al-Qur’an hari ini.',
      );
    }
  }

  Future<void> _scheduleDaily(
    int id,
    tz.TZDateTime time,
    String title,
    String body,
  ) => _plugin.zonedSchedule(
    id,
    title,
    body,
    time,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'ibadah_reminders',
        'Pengingat ibadah',
        channelDescription: 'Jadwal salat dan pengingat tilawah',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );

  Future<void> _schedule(
    int id,
    tz.TZDateTime time,
    String title,
    String body,
  ) => _plugin.zonedSchedule(
    id,
    title,
    body,
    time,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'ibadah_reminders',
        'Pengingat ibadah',
        channelDescription: 'Jadwal salat dan pengingat tilawah',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
