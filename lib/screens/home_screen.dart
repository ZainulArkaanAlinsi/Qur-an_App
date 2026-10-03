import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/app_dock.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/home/application/home_controller.dart';
import 'package:quran_app_2025/features/home/domain/next_step.dart';
import 'package:quran_app_2025/features/home/domain/today_summary.dart';
import 'package:quran_app_2025/features/home/presentation/next_step_card.dart';
import 'package:quran_app_2025/features/home/presentation/prayer_horizon.dart';
import 'package:quran_app_2025/features/home/presentation/today_card.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/prayer/presentation/prayer_settings_sheet.dart';
import 'package:quran_app_2025/features/session/presentation/session_screen.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/murottal_screen.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/quran_search_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/prayer_service.dart';

/// Beranda v6 (docs/design/v6/screens/19-beranda.md, acuan V6-Beranda.png).
///
/// Dalam 3 detik pengguna tahu salat berikutnya kapan dan **satu hal** yang
/// sebaiknya dikerjakan sekarang. Urutan: tanggal + cari/bookmark, sapaan,
/// horizon salat, kartu "Langkah berikutnya", label HARI INI + Progres,
/// kartu Hari ini. Semua angka dari [HomeController]; keputusannya fungsi
/// murni di `lib/features/home/domain/`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuran,
    required this.onOpenLearn,
    this.onOpenHafalan,
    this.prayerLoader,
    this.now,
    this.audio,
  });

  /// Pindah ke tab Qur'an.
  final VoidCallback onOpenQuran;

  /// Pindah ke tab Belajar ("Sesi besok").
  final VoidCallback onOpenLearn;

  /// Pindah ke tab Hafalan (murajaah, keputusan 2026-10-02).
  final VoidCallback? onOpenHafalan;

  /// Hanya untuk tes: jadwal salat tanpa jaringan.
  @visibleForTesting
  final Future<PrayerDay?> Function()? prayerLoader;

  /// Hanya untuk tes: jam yang dibekukan.
  @visibleForTesting
  final DateTime Function()? now;

  /// Hanya untuk tes: pemutar palsu ("murottal diputar").
  @visibleForTesting
  final NowPlayingAudio? audio;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller = HomeController(
    clock: widget.now ?? DateTime.now,
    loadPrayer: widget.prayerLoader == null
        ? null
        : (_) => widget.prayerLoader!(),
    audio: widget.audio ?? QuranNowPlayingAudio(),
  );
  final Future<List<String>> _arabicNames = SuraNamesRepository.load();

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Layar lain dibuka; setelah kembali, semua angka dihitung ulang.
  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .then((_) {
        if (mounted) unawaited(_controller.refresh());
      });

  void _act(NextStepAction action) {
    final last = _controller.snapshot.lastRead;
    switch (action) {
      case NextStepAction.openSession:
        _push(SessionScreen(now: widget.now));
      case NextStepAction.openHafalan:
        (widget.onOpenHafalan ?? () {})();
      case NextStepAction.openReader:
        final surah = surahCatalog[(last?.surah ?? 1) - 1];
        _push(ReaderScreen(surah: surah, initialVerse: last?.ayah ?? 1));
      case NextStepAction.openPlayer:
        _push(const MurottalScreen());
      case NextStepAction.openLearn:
        widget.onOpenLearn();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final tokens = Theme.of(context).extension<SacredTokens>()!;
      final snapshot = _controller.snapshot;
      final next = decideNextStep(snapshot);
      final today = summarizeToday(snapshot);
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          // Ruang untuk dock; bertambah saat murottal diputar.
          padding: EdgeInsets.only(bottom: AppDock.reservedHeightOf(context)),
          children: [
            _Header(
              now: snapshot.now,
              prayer: snapshot.prayer,
              onSearch: () => _push(const QuranSearchScreen()),
              onBookmark: () => _push(const BookmarkScreen()),
            ),
            const SizedBox(height: 12),
            const _Greeting(),
            const SizedBox(height: 14),
            // Gutter layar v6: 20 (DESIGN v6 §4).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrayerHorizon(
                    snapshot: snapshot,
                    now: _now,
                    onOpen: () => _push(const PrayerScreen()),
                    // Lembar Waktu salat; Beranda memuat ulang sendiri
                    // lewat PrayerSettingsStore.revision setelah disimpan.
                    onSetCity: () => unawaited(
                      showPrayerSettingsSheet(
                        context,
                        preview: snapshot.prayer,
                      ),
                    ),
                    onSettings: () => unawaited(
                      showPrayerSettingsSheet(
                        context,
                        preview: snapshot.prayer,
                      ),
                    ),
                    onRetry: () => unawaited(_controller.refresh()),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<String>>(
                    future: _arabicNames,
                    builder: (context, names) {
                      final surah = snapshot.lastRead?.surah ?? 1;
                      final list = names.data;
                      return NextStepCard(
                        result: next,
                        onAction: _act,
                        arabicName: list != null && surah <= list.length
                            ? list[surah - 1]
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(
                    tokens: tokens,
                    onProgress: () => _push(const ProgressScreen()),
                  ),
                  const SizedBox(height: 8),
                  TodayCard(
                    summary: today,
                    today: snapshot.now,
                    onTap: () => _push(const ProgressScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Label "HARI INI" + tautan "Progres" di kanan.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.tokens, required this.onProgress});

  final SacredTokens tokens;
  final VoidCallback onProgress;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            'HARI INI',
            style: SacredText.eyebrow.copyWith(color: tokens.sec),
          ),
        ),
      ),
      Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onProgress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'Progres',
              style: SacredText.linkLabel.copyWith(color: tokens.primaryText),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Tanggal Masehi + Hijriah (satu baris, bulan Indonesia), tombol Cari dan
/// Bookmark 40 di kanan.
class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.prayer,
    required this.onSearch,
    required this.onBookmark,
  });

  final DateTime now;
  final PrayerDay? prayer;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;

  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_days[now.weekday - 1]}, ${now.day} '
                  '${_months[now.month - 1]}',
                  // Teks besar boleh turun baris; tanggal tidak dipotong.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.dateLine.copyWith(color: tokens.ink),
                ),
                // Hijriah datang dari AlAdhan; kalau luring, barisnya
                // dikosongkan, bukan diisi tebakan.
                if (prayer case final day?)
                  Text(
                    day.hijriIndonesian,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.dateSub.copyWith(color: tokens.sec),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RoundIconButton(
            icon: SacredIcons.search,
            tooltip: 'Cari ayat atau surah',
            surface: true,
            onTap: onSearch,
          ),
          const SizedBox(width: 4),
          RoundIconButton(
            icon: SacredIcons.bookmark,
            tooltip: 'Bookmark',
            surface: true,
            onTap: onBookmark,
          ),
        ],
      ),
    );
  }
}

/// "Assalamu'alaikum," + nama depan akun, atau "Sahabat Qur'an".
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ValueListenableBuilder<SyncAccount?>(
        valueListenable: AccountService.instance.account,
        builder: (context, account, _) {
          final name = account?.name?.trim().split(' ').first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalamu’alaikum,',
                style: SacredText.greetingSmall.copyWith(color: tokens.sec),
              ),
              Text(
                name == null || name.isEmpty ? 'Sahabat Qur’an' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SacredText.homeNameV6.copyWith(color: tokens.ink),
              ),
            ],
          );
        },
      ),
    );
  }
}
