import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/home/domain/prayer_horizon.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart'
    show showDraftLessons;
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Membangun [HomeSnapshot] dari layanan yang sudah ada (docs/DATA.md §1)
/// dan menghitungnya ulang ketika:
/// - aplikasi kembali ke depan;
/// - `sessionRevision` berubah (sesi hari ini disimpan);
/// - antrean/ayat murottal berubah;
/// - [refresh] dipanggil (pull-to-refresh, kembali dari layar lain);
/// - **tanggal lokal berganti** (timer ke 00:00:05 berikutnya).
class HomeController extends ChangeNotifier with WidgetsBindingObserver {
  HomeController({
    DateTime Function()? clock,
    Future<PrayerDay?> Function(DateTime day)? loadPrayer,
    Future<Curriculum> Function()? loadCurriculum,
    Future<List<PageBoundary>> Function()? loadPages,
    NowPlayingAudio? audio,
    Listenable? sessionChanges,
  }) : _clock = clock ?? DateTime.now,
       _loadPrayerFor = loadPrayer ?? _fetchPrayer,
       _loadCurriculum = loadCurriculum ?? CurriculumRepository.load,
       _loadPages = loadPages ?? PageRepository.load,
       _audio = audio,
       _sessionChanges = sessionChanges ?? sessionRevision;

  final DateTime Function() _clock;
  final Future<PrayerDay?> Function(DateTime day) _loadPrayerFor;
  final Future<Curriculum> Function() _loadCurriculum;
  final Future<List<PageBoundary>> Function() _loadPages;
  final NowPlayingAudio? _audio;
  final Listenable _sessionChanges;

  Curriculum? _curriculum;
  List<PageBoundary> _pages = const [];
  PrayerDay? _prayer;
  PrayerDay? _prayerTomorrow;
  PrayerStatus _prayerStatus = PrayerStatus.memuat;
  Timer? _midnight;
  bool _started = false;
  bool _disposed = false;
  HomeSnapshot? _snapshot;

  /// Snapshot terakhir; dibangun saat pertama dibaca bila belum ada.
  HomeSnapshot get snapshot => _snapshot ??= _build();

  /// Mulai mendengarkan perubahan dan memuat data yang butuh waktu.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _audio?.addListener(_recompute);
    _sessionChanges.addListener(_recompute);
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    try {
      _curriculum = await _loadCurriculum();
    } on Object {
      _curriculum = null; // Tanpa kurikulum: sesi dianggap belum tersedia.
    }
    try {
      _pages = await _loadPages();
    } on Object {
      _pages = const []; // Tanpa halaman: pill "Hal." disembunyikan.
    }
    _recompute();
    await _refreshPrayer();
  }

  /// Muat ulang jadwal salat lalu hitung ulang semua angka.
  Future<void> refresh() async {
    _recompute();
    await _refreshPrayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final day = _prayer?.gregorianDate;
    final now = _clock();
    final stale =
        day == null ||
        day.year != now.year ||
        day.month != now.month ||
        day.day != now.day;
    _scheduleMidnight();
    if (stale) {
      unawaited(refresh());
    } else {
      _recompute();
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      if (_disposed) return;
      _scheduleMidnight();
      unawaited(refresh());
    });
  }

  Future<void> _refreshPrayer() async {
    final now = _clock();
    if (SharedPreferencesService.getPrayerCity().trim().isEmpty) {
      _prayer = null;
      _prayerTomorrow = null;
      _prayerStatus = PrayerStatus.belumDiatur;
      _recompute();
      return;
    }
    if (_prayer == null) {
      _prayerStatus = PrayerStatus.memuat;
      _recompute();
    }
    PrayerDay? day;
    try {
      day = await _loadPrayerFor(now);
    } on Object {
      day = null;
    }
    if (_disposed) return;
    _prayer = day;
    _prayerTomorrow = null;
    _prayerStatus = day == null ? PrayerStatus.luring : PrayerStatus.ok;
    // Setelah Isya: jadwal besok untuk "Subuh besok"; gagal → tanpa jam.
    if (day != null && (buildHorizon(day, now)?.isTomorrow ?? false)) {
      try {
        _prayerTomorrow = await _loadPrayerFor(
          now.add(const Duration(days: 1)),
        );
      } on Object {
        _prayerTomorrow = null;
      }
    }
    if (_disposed) return;
    _recompute();
  }

  void _recompute() {
    if (_disposed) return;
    _snapshot = _build();
    notifyListeners();
  }

  HomeSnapshot _build() {
    final now = _clock();
    final lastSurah = SharedPreferencesService.getLastReadSurah();
    LastRead? lastRead;
    if (lastSurah != null) {
      final ayah = SharedPreferencesService.getLastReadVerse(lastSurah);
      lastRead = LastRead(
        surah: lastSurah,
        ayah: ayah,
        page: _pageOf(lastSurah, ayah),
      );
    }
    final curriculum = _curriculum;
    final all = SharedPreferencesService.allAyahMemorization();
    final audio = _audio;
    final playingAyah = NowPlayingAudio.ayahOf(audio?.playingVerse);
    final queue = audio?.queue;
    return HomeSnapshot(
      now: now,
      lastRead: lastRead,
      reading: ReadingProgressService.read(now: now),
      session: SessionStore.app?.day(ReadingProgressService.localDate(now)),
      sessionAvailable:
          curriculum?.visible(includeDrafts: showDraftLessons).isNotEmpty ??
          false,
      memorizedCount: all.length,
      murajaahDue: dueForReview(all, now),
      murajaahDoneToday: SharedPreferencesService.getMurajaahDone(now),
      startPoint: StartPoint.saved ?? StartPoint.initial,
      nextLesson: curriculum?.nextAfter(
        SharedPreferencesService.getCompletedLessons(),
        includeDrafts: showDraftLessons,
      ),
      prayer: _prayer,
      prayerTomorrow: _prayerTomorrow,
      prayerStatus: _prayerStatus,
      nowPlaying: queue == null || playingAyah == null
          ? null
          : NowPlaying(surah: queue.surah, ayah: playingAyah),
    );
  }

  /// Halaman mushaf Madinah tempat ayat berada (sama dengan Beranda lama).
  int? _pageOf(int surah, int ayah) {
    int? number;
    for (final boundary in _pages) {
      final before =
          boundary.surah < surah ||
          (boundary.surah == surah && boundary.verse <= ayah);
      if (before) number = boundary.number;
    }
    return number;
  }

  static Future<PrayerDay?> _fetchPrayer(DateTime day) => PrayerService.fetch(
    city: SharedPreferencesService.getPrayerCity(),
    country: SharedPreferencesService.getPrayerCountry(),
    date: day,
  );

  @override
  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    _audio?.removeListener(_recompute);
    _sessionChanges.removeListener(_recompute);
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
