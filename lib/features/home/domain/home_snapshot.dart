import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';

/// Posisi baca terakhir (docs/DATA.md §1).
@immutable
class LastRead {
  const LastRead({required this.surah, required this.ayah, this.page});

  final int surah;
  final int ayah;

  /// Halaman mushaf Madinah, bila metadata halaman sudah dimuat.
  final int? page;
}

/// Murottal yang sedang dimuat (surah + ayat yang diputar).
@immutable
class NowPlaying {
  const NowPlaying({required this.surah, required this.ayah});

  final int surah;
  final int ayah;
}

/// Keadaan jadwal salat di Beranda (19-beranda.md §3).
enum PrayerStatus { ok, belumDiatur, luring, memuat }

/// Semua angka Beranda pada satu saat (docs/DATA.md §1). Dibangun
/// `HomeController` dari layanan yang sudah ada; fungsi keputusan
/// (`decideNextStep`, `summarizeToday`, `buildHorizon`) hanya membaca ini.
@immutable
class HomeSnapshot {
  const HomeSnapshot({
    required this.now,
    required this.reading,
    this.lastRead,
    this.session,
    this.sessionAvailable = false,
    this.warmupCount,
    this.memorizedCount = 0,
    this.murajaahDue = const [],
    this.murajaahDoneToday = 0,
    this.startPoint = StartPoint.initial,
    this.nextLesson,
    this.prayer,
    this.prayerTomorrow,
    this.prayerStatus = PrayerStatus.memuat,
    this.nowPlaying,
  });

  final DateTime now;
  final LastRead? lastRead;
  final ReadingProgress reading;

  /// Sesi hari ini, atau null bila belum dibuka.
  final DailySession? session;

  /// Ada minimal satu pelajaran terbit (atau draf di build debug).
  final bool sessionAvailable;

  /// Jumlah soal pemanasan dari rencana sesi, bila sudah diketahui.
  final int? warmupCount;
  final int memorizedCount;

  /// Ayat yang jatuh tempo, urut dari yang paling lama terlewat.
  final List<AyahMemorization> murajaahDue;

  /// Kunci `murajaah.selesai.<tanggal>` hari ini (DATA §4).
  final int murajaahDoneToday;
  final StartPoint startPoint;

  /// Pelajaran berikutnya, untuk "Sesi besok".
  final Lesson? nextLesson;
  final PrayerDay? prayer;

  /// Jadwal besok, untuk "Subuh besok" setelah Isya; boleh null.
  final PrayerDay? prayerTomorrow;
  final PrayerStatus prayerStatus;
  final NowPlaying? nowPlaying;

  /// Tengah malam tanggal lokal [now].
  DateTime get today => DateTime(now.year, now.month, now.day);

  /// Sesi hari ini sudah selesai.
  bool get sessionCompleted => session?.completed ?? false;
}
