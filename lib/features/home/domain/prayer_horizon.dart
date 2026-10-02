import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// Satu titik di horizon salat.
@immutable
class HorizonNode {
  const HorizonNode({required this.label, required this.time});

  /// "Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya".
  final String label;

  /// Jam dinding kota, "HH:mm" seperti dari AlAdhan.
  final String time;
}

/// Model horizon lima waktu (docs/DATA.md §5.1).
@immutable
class HorizonModel {
  const HorizonModel({
    required this.nodes,
    required this.nextIndex,
    required this.isTomorrow,
    required this.nowPosition,
    required this.untilNext,
    this.tomorrowTime,
  });

  /// 5 titik: Subuh, Dzuhur, Ashar, Maghrib, Isya. Imsak/Terbit tidak masuk.
  final List<HorizonNode> nodes;

  /// Salat berikutnya (0..4); 0 dengan [isTomorrow] setelah Isya.
  final int nextIndex;
  final bool isTomorrow;

  /// 0..1 di sepanjang lintasan (titik berjarak sama): `(i + (now − t[i]) /
  /// (t[i+1] − t[i])) / 4`. Sebelum Subuh 0, setelah Isya 1.
  final double nowPosition;

  /// Sampai salat berikutnya; null bila jam Subuh besok belum diketahui.
  final Duration? untilNext;

  /// Jam Subuh besok ("HH:mm"), bila jadwal besok sudah ada.
  final String? tomorrowTime;
}

/// Horizon dari [day] pada [now]. Waktu dibandingkan sebagai instan di zona
/// kota (`PrayerDay.timezone`), bukan zona HP, seperti strip salat lama.
/// Kalau zona kota tidak diketahui, jam dinding HP yang dipakai.
///
/// Null bila salah satu dari lima waktu tidak ada (data tidak lengkap).
HorizonModel? buildHorizon(PrayerDay day, DateTime now, {PrayerDay? tomorrow}) {
  const labels = PrayerService.prayerNames;
  final times = <DateTime>[];
  for (final label in labels) {
    final at = _instant(day, label);
    if (at == null || day.prayers[label] == null) return null;
    times.add(at);
  }
  final nodes = [
    for (final label in labels)
      HorizonNode(label: label, time: day.prayers[label]!),
  ];

  // Salat berikutnya: yang pertama setelah [now] (tepat di jam salat berarti
  // salat itu sudah masuk, sama dengan PrayerDay.nextLabelAt).
  final next = times.indexWhere((t) => t.isAfter(now));
  if (next == -1) {
    final subuh = tomorrow == null ? null : _instant(tomorrow, labels.first);
    return HorizonModel(
      nodes: nodes,
      nextIndex: 0,
      isTomorrow: true,
      nowPosition: 1,
      untilNext: subuh?.difference(now),
      tomorrowTime: tomorrow?.prayers[labels.first],
    );
  }
  final double position;
  if (next == 0) {
    position = 0;
  } else {
    final prev = times[next - 1];
    final span = times[next].difference(prev).inSeconds;
    final passed = now.difference(prev).inSeconds;
    final within = span <= 0 ? 0.0 : (passed / span).clamp(0.0, 1.0);
    position = ((next - 1) + within) / (labels.length - 1);
  }
  return HorizonModel(
    nodes: nodes,
    nextIndex: next,
    isTomorrow: false,
    nowPosition: position,
    untilNext: times[next].difference(now),
  );
}

/// "{m} m lagi" di bawah satu jam, selain itu "{j} j {m} m lagi".
String horizonCountdown(Duration left) {
  final minutes = left.inMinutes.clamp(0, 1 << 30);
  if (minutes < 60) return '$minutes m lagi';
  return '${minutes ~/ 60} j ${minutes % 60} m lagi';
}

/// Instan salat [label]: di zona kota bila diketahui, selain itu jam dinding
/// lokal HP pada tanggal [day].
DateTime? _instant(PrayerDay day, String label) {
  final wall = day.timeFor(label);
  if (wall == null) return null;
  final zone = day.timezone;
  if (zone == null) return wall;
  try {
    final location = tz.getLocation(zone);
    return tz.TZDateTime(
      location,
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    );
  } on Object {
    return wall;
  }
}
