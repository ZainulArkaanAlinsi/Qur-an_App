import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/home/domain/next_step.dart';

enum TodayRingKind { baca, sesi, murajaah }

/// Satu cincin kartu "Hari ini" (docs/DATA.md §3).
@immutable
class TodayRing {
  const TodayRing({
    required this.kind,
    required this.value,
    required this.total,
    required this.fill,
    this.note,
  });

  final TodayRingKind kind;

  /// Menit dibaca / langkah sesi / ayat dimurajaah.
  final int value;

  /// Target menit / 5 langkah / ayat terjadwal hari ini.
  final int total;

  /// 0..1.
  final double fill;

  /// Keterangan pengganti angka, mis. "Tidak ada jadwal".
  final String? note;

  bool get full => fill >= 1;
}

@immutable
class TodaySummary {
  const TodaySummary({
    required this.rings,
    required this.week,
    required this.streak,
    this.hint,
  });

  /// Urut luar → dalam: Baca, Sesi (bila ada materi), Murajaah (bila sudah
  /// pernah menghafal).
  final List<TodayRing> rings;

  /// Kalimat bantu, paling banyak satu (DATA §3).
  final String? hint;

  /// 7 hari terakhir, terlama dulu; elemen terakhir = hari ini.
  final List<bool> week;
  final int streak;
}

/// Kartu "Hari ini" dari [s]. Tidak pernah membagi nol, dan tidak menyebut
/// keutamaan/pahala apa pun (aturan konten).
TodaySummary summarizeToday(HomeSnapshot s) {
  final reading = s.reading;
  final readFill = reading.targetSeconds <= 0
      ? (reading.todaySeconds > 0 ? 1.0 : 0.0)
      : math.min(1.0, reading.todaySeconds / reading.targetSeconds);
  final session = s.session;
  final steps = session == null
      ? 0
      : session.completed
      ? sessionStepCount
      : session.step.index;
  final done = s.murajaahDoneToday;
  final scheduled = done + s.murajaahDue.length;

  final rings = <TodayRing>[
    TodayRing(
      kind: TodayRingKind.baca,
      value: reading.todaySeconds ~/ 60,
      total: reading.targetSeconds ~/ 60,
      fill: readFill,
    ),
    if (s.sessionAvailable)
      TodayRing(
        kind: TodayRingKind.sesi,
        value: steps,
        total: sessionStepCount,
        fill: steps / sessionStepCount,
      ),
    if (s.memorizedCount > 0)
      TodayRing(
        kind: TodayRingKind.murajaah,
        value: done,
        total: scheduled,
        // Tanpa jadwal hari ini cincinnya kosong, bukan penuh.
        fill: scheduled == 0 ? 0 : done / scheduled,
        note: scheduled == 0 ? 'Tidak ada jadwal' : null,
      ),
  ];

  final String? hint;
  if (reading.todaySeconds == 0 &&
      steps == 0 &&
      done == 0 &&
      reading.currentStreak == 0) {
    hint = 'Hari pertama. Lima menit membaca sudah cukup untuk mulai.';
  } else if (rings
      // Murajaah tanpa jadwal tidak menahan "semua tercapai": tidak ada
      // yang perlu dikerjakan di sana.
      .where((ring) => ring.note == null)
      .every((ring) => ring.full)) {
    hint = 'Semua target hari ini tercapai. Alhamdulillah.';
  } else {
    hint = null;
  }

  final recent = reading.recentDays;
  final week = [
    for (var i = 0; i < 7 - recent.length; i++) false,
    ...recent.length > 7 ? recent.sublist(recent.length - 7) : recent,
  ];
  return TodaySummary(
    rings: rings,
    hint: hint,
    week: week,
    streak: reading.currentStreak,
  );
}
