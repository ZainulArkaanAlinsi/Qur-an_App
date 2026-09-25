import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_circle_button.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/quran_search_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Beranda v2 (docs/design/v2/screens/01-beranda.md, acuan V2-Beranda.png).
///
/// Urutan: tanggal + cari/bookmark, sapaan, kartu hero lanjut membaca,
/// target & istiqamah, grup HARI INI (belajar, murajaah), strip salat.
/// Semua angka dari perangkat; tiap elemen membawa ke tempat yang diharapkan
/// orang ketika mengetuknya.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuran,
    required this.onOpenLearn,
    this.onOpenHafalan,
    this.prayerLoader,
    this.now,
  });

  /// Pindah ke tab Qur'an.
  final VoidCallback onOpenQuran;

  /// Pindah ke tab Belajar.
  final VoidCallback onOpenLearn;

  /// Pindah ke tab Hafalan.
  final VoidCallback? onOpenHafalan;

  /// Hanya untuk tes: jadwal salat tanpa jaringan.
  @visibleForTesting
  final Future<PrayerDay?> Function()? prayerLoader;

  /// Hanya untuk tes: jam yang dibekukan.
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _data = _load();
  late Future<PrayerDay?> _prayer = _loadPrayer();
  final Future<Curriculum> _curriculum = CurriculumRepository.load();

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  /// Data dari perangkat sendiri; tidak menunggu jaringan supaya beranda
  /// tetap lengkap saat luring.
  Future<_HomeData> _load() async {
    var juz = const <JuzBoundary>[];
    var pages = const <PageBoundary>[];
    var names = const <String>[];
    try {
      juz = await JuzRepository.load();
      pages = await PageRepository.load();
      names = await SuraNamesRepository.load();
    } on Object {
      // Juz, halaman, atau nama Arab hilang; isi lainnya tetap tampil.
    }
    return _HomeData(juz: juz, pages: pages, arabicNames: names);
  }

  Future<PrayerDay?> _loadPrayer() async {
    final loader = widget.prayerLoader;
    if (loader != null) return loader();
    try {
      return await PrayerService.fetch(
        city: SharedPreferencesService.getPrayerCity(),
        country: SharedPreferencesService.getPrayerCountry(),
      );
    } on Object {
      return null; // Luring: strip salat menampilkan keadaan sebenarnya.
    }
  }

  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .then((_) {
        // Kembali dari membaca/latihan: angka target, istiqamah, dan
        // murajaah dihitung ulang.
        if (mounted) setState(() {});
      });

  Future<void> _listen(SurahMeta surah, int verse) async {
    try {
      await QuranAudioService.instance.toggle(surah: surah.number, ayah: verse);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Murottal belum dapat diputar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final lastRead = SharedPreferencesService.getLastReadSurah();
    final surah = surahCatalog.firstWhere(
      (item) => item.number == lastRead,
      orElse: () => surahCatalog.first,
    );
    final verse = lastRead == null
        ? 1
        : SharedPreferencesService.getLastReadVerse(surah.number);
    final progress = ReadingProgressService.read(now: now);

    return FutureBuilder<_HomeData>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _data = _load();
            _prayer = _loadPrayer();
          }),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            // Ruang untuk tab bar mengambang.
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _Header(
                now: now,
                prayer: _prayer,
                onSearch: () => _push(const QuranSearchScreen()),
                onBookmark: () => _push(const BookmarkScreen()),
              ),
              const SizedBox(height: 12),
              const _Greeting(),
              const SizedBox(height: 14),
              _HeroCard(
                surah: surah,
                verse: verse,
                started: lastRead != null,
                page: data?.pageOf(surah.number, verse),
                juz: data?.juzOf(surah.number, verse),
                arabicName: data?.arabicNameOf(surah.number),
                onContinue: () =>
                    _push(ReaderScreen(surah: surah, initialVerse: verse)),
                onListen: () => _listen(surah, verse),
              ),
              const SizedBox(height: 12),
              _TargetAndStreak(
                progress: progress,
                now: now,
                onTap: () => _push(const ProgressScreen()),
              ),
              const SizedBox(height: 18),
              _TodayList(
                curriculum: _curriculum,
                now: now,
                onOpenLearn: widget.onOpenLearn,
                onOpenHafalan: widget.onOpenHafalan ?? () {},
              ),
              const SizedBox(height: 12),
              _PrayerStrip(
                future: _prayer,
                now: _now,
                onTap: () => _push(const PrayerScreen()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Teks sangat besar (pengaturan aksesibilitas): tata letak dua kolom dan
/// hiasan dilepas supaya teks tetap utuh.
bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;

class _HomeData {
  const _HomeData({
    required this.juz,
    required this.pages,
    required this.arabicNames,
  });

  final List<JuzBoundary> juz;
  final List<PageBoundary> pages;
  final List<String> arabicNames;

  String? arabicNameOf(int surah) =>
      surah <= arabicNames.length ? arabicNames[surah - 1] : null;

  static bool _atOrBefore(int surah, int verse, int atSurah, int atVerse) =>
      surah < atSurah || (surah == atSurah && verse <= atVerse);

  /// Juz tempat ayat berada, dari batas Tanzil yang tervalidasi.
  int? juzOf(int surah, int ayah) {
    int? number;
    for (final boundary in juz) {
      if (_atOrBefore(boundary.surah, boundary.verse, surah, ayah)) {
        number = boundary.number;
      }
    }
    return number;
  }

  /// Halaman mushaf Madinah tempat ayat berada.
  int? pageOf(int surah, int ayah) {
    int? number;
    for (final boundary in pages) {
      if (_atOrBefore(boundary.surah, boundary.verse, surah, ayah)) {
        number = boundary.number;
      }
    }
    return number;
  }
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
  final Future<PrayerDay?> prayer;
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
                FutureBuilder<PrayerDay?>(
                  future: prayer,
                  builder: (context, snapshot) {
                    final day = snapshot.data;
                    // Hijriah datang dari AlAdhan; kalau luring, barisnya
                    // dikosongkan, bukan diisi tebakan.
                    if (day == null) return const SizedBox.shrink();
                    return Text(
                      day.hijriIndonesian,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.dateSub.copyWith(color: tokens.sec),
                    );
                  },
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
                style: SacredText.homeName.copyWith(color: tokens.ink),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu hero: sampul mihrab 76×98 berisi nama surah Arab, "LANJUTKAN
/// MEMBACA", nama surah, "Halaman · Juz · Ayat", tombol emas Lanjutkan dan
/// tombol dengar 48. Belum pernah membaca: mulai dari Al-Fatihah.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.surah,
    required this.verse,
    required this.started,
    required this.page,
    required this.juz,
    required this.arabicName,
    required this.onContinue,
    required this.onListen,
  });

  final SurahMeta surah;
  final int verse;
  final bool started;
  final int? page;
  final int? juz;
  final String? arabicName;
  final VoidCallback onContinue;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final large = _largeText(context);
    final info = [
      if (page != null) 'Halaman $page',
      if (juz != null) 'Juz $juz',
      'Ayat $verse',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: tokens.art,
                child: GeometricPattern(
                  tile: 46,
                  opacity: .10,
                  color: tokens.artInk,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Sampul hanya hiasan; nama surah sudah tertulis.
                      if (!large) ...[
                        _MihrabCover(arabicName: arabicName),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              started ? 'LANJUTKAN MEMBACA' : 'MULAI MEMBACA',
                              style: SacredText.eyebrow.copyWith(
                                color: tokens.artInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              surah.displayName,
                              maxLines: large ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.heroTitleV2.copyWith(
                                color: SacredArt.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              info,
                              maxLines: large ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.dateSub.copyWith(
                                color: SacredArt.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SacredButton(
                          label: started ? 'Lanjutkan' : 'Mulai',
                          icon: SacredIcons.play,
                          iconFilled: true,
                          tone: ButtonTone.gold,
                          expand: true,
                          onTap: onContinue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ikon saja: label "Dengarkan" dulu terpotong.
                      _ListenButton(onTap: onListen),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol dengar berkaca di atas kartu hero (LIQUID_GLASS.md §2: tombol
/// bulat mengambang, diameter 44). Ikonnya berganti jeda selama murottal
/// sedang diputar, supaya orang tahu ketukannya berhasil.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: QuranAudioService.instance.isPlaying,
      builder: (context, playing, _) => GlassCircleButton(
        icon: playing ? SacredIcons.pause : SacredIcons.headphones,
        filled: playing,
        tooltip: playing ? 'Jeda murottal' : 'Dengarkan murottal',
        strokeWidth: SacredIcons.strokeNav,
        onTap: onTap,
      ),
    );
  }
}

/// Sampul mihrab 76×98 (path persis dari V2-Beranda.html).
class _MihrabCover extends StatelessWidget {
  const _MihrabCover({required this.arabicName});

  final String? arabicName;

  static const _path =
      'M0 86 L0 38.0 C0 16.0 22.8 6.1 38.0 0 C53.2 6.1 76 16.0 76 38.0 '
      'L76 86 Q76 98 64 98 L12 98 Q0 98 0 86 Z';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox(
      width: 76,
      height: 98,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CoverPainter(outline: tokens.artInk)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            // Ukuran sampul tetap, jadi teks di dalamnya tidak ikut diskalakan.
            child: Text(
              textScaler: TextScaler.noScaling,
              arabicName ?? '',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontFamily: SacredText.quran,
                fontSize: 20,
                height: 36 / 20,
                color: tokens.artInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter({required this.outline});

  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = parseSvgPath(_MihrabCover._path);
    canvas.drawPath(path, Paint()..color = SacredArt.plate);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.outline != outline;
}

/// Dua kartu sejajar: Target baca dan Istiqamah. Keduanya membuka Progres.
class _TargetAndStreak extends StatelessWidget {
  const _TargetAndStreak({
    required this.progress,
    required this.now,
    required this.onTap,
  });

  final ReadingProgress progress;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = _Tappable(
      label: 'Target baca, buka progres',
      onTap: onTap,
      child: _TargetCard(progress: progress),
    );
    final streak = _Tappable(
      label: 'Istiqamah, buka progres',
      onTap: onTap,
      child: _StreakCard(progress: progress, now: now),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Teks sangat besar: kartu ditumpuk supaya labelnya tidak terpotong.
      child: _largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [target, const SizedBox(height: 12), streak],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: target),
                  const SizedBox(width: 12),
                  Expanded(child: streak),
                ],
              ),
            ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: label,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    ),
  );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final minutes = progress.todaySeconds ~/ 60;
    final target = (progress.targetSeconds / 60).round();
    final remaining = (progress.remainingSeconds / 60).ceil();
    final fraction = progress.targetSeconds <= 0
        ? 1.0
        : progress.todaySeconds / progress.targetSeconds;
    return SacredCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target baca',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SacredText.cardLabel.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ProgressRing(value: fraction),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$minutes'),
                          TextSpan(
                            text: '/$target mnt',
                            style: SacredText.metricUnit.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: SacredText.metric.copyWith(color: tokens.ink),
                    ),
                    Text(
                      progress.completedToday
                          ? 'Target tercapai'
                          : '$remaining mnt lagi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.progress, required this.now});

  final ReadingProgress progress;
  final DateTime now;

  /// Huruf hari Indonesia, Senin di indeks 0 seperti `DateTime.weekday`.
  static const _letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  /// Pekan berjalan Senin–Minggu. Hari yang belum datang dibiarkan kosong,
  /// bukan ditandai gagal.
  List<_Day> _week() {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        () {
          final date = DateTime(monday.year, monday.month, monday.day + i);
          final key = ReadingProgressService.localDate(date);
          final seconds = SharedPreferencesService.getReadingSeconds(key);
          final target = SharedPreferencesService.getTargetForDate(key);
          return _Day(
            letter: _letters[i],
            done: target > 0 && seconds >= target,
            isToday: i == now.weekday - 1,
            isFuture: i > now.weekday - 1,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SacredCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Istiqamah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.cardLabel.copyWith(color: tokens.sec),
                ),
              ),
              LineIcon(
                SacredIcons.flame,
                color: tokens.goldText,
                size: 18,
                strokeWidth: SacredIcons.strokeAction,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${progress.currentStreak}',
                style: SacredText.metric.copyWith(color: tokens.ink),
              ),
              const SizedBox(width: 6),
              Text(
                'hari',
                style: SacredText.metricUnit.copyWith(color: tokens.sec),
              ),
              // Kemarin tercapai tetapi hari ini belum: istiqamahnya menunggu
              // bacaan hari ini, belum putus. Pill memakai seluruh sisa ruang
              // dan hanya mengecil bila benar-benar tidak muat.
              Expanded(
                child: progress.pendingToday
                    ? const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusPill('MENUNGGU'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in _week()) _DayDot(day: day)],
          ),
        ],
      ),
    );
  }
}

class _Day {
  const _Day({
    required this.letter,
    required this.done,
    required this.isToday,
    required this.isFuture,
  });

  final String letter;
  final bool done;
  final bool isToday;
  final bool isFuture;
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final _Day day;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final state = day.done
        ? 'target tercapai'
        : day.isFuture
        ? 'belum datang'
        : day.isToday
        ? 'hari ini, belum tercapai'
        : 'tidak tercapai';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${day.letter}: $state',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 13,
            child: day.isToday && !day.done
                // Hari ini belum tercapai: lingkaran putus-putus.
                ? CustomPaint(painter: _DashedRing(color: tokens.gold))
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.done ? tokens.gold : tokens.surf2,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            day.letter,
            style: SacredText.dayLetter.copyWith(
              color: day.isToday ? tokens.ink : tokens.sec,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  const _DashedRing({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const segments = 6;
    const sweep = math.pi * 2 / segments * .55;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 2 / segments * i,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

/// Grup HARI INI: lanjutkan belajar dan murajaah.
class _TodayList extends StatelessWidget {
  const _TodayList({
    required this.curriculum,
    required this.now,
    required this.onOpenLearn,
    required this.onOpenHafalan,
  });

  final Future<Curriculum> curriculum;
  final DateTime now;
  final VoidCallback onOpenLearn;
  final VoidCallback onOpenHafalan;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Curriculum>(
      future: curriculum,
      builder: (context, snapshot) {
        final learn = snapshot.data == null
            ? null
            : _learnRow(context, snapshot.data!);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GroupedList(
            label: 'Hari ini',
            children: [?learn, _murajaahRow(context)],
          ),
        );
      },
    );
  }

  /// Tahap berikutnya dari jalur belajar. Cincin = tahap selesai dari yang
  /// boleh tampil. Hilang bila belum ada materi terbit.
  Widget? _learnRow(BuildContext context, Curriculum curriculum) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final visible = curriculum.visible(includeDrafts: showDraftLessons);
    if (visible.isEmpty) return null;
    final done = SharedPreferencesService.getCompletedLessons();
    final next = curriculum.nextAfter(done, includeDrafts: showDraftLessons);
    final completed = curriculum.completedCount(
      done,
      includeDrafts: showDraftLessons,
    );
    return ListRow(
      leading: ProgressRing(
        value: completed / visible.length,
        size: 44,
        stroke: 5,
        child: LineIcon(SacredIcons.cap, color: tokens.primaryText, size: 18),
      ),
      title: next == null ? 'Belajar' : 'Lanjutkan belajar',
      subtitle: next == null
          ? 'Semua $completed tahap selesai'
          : 'Tahap ${next.level} · ${next.title} · '
                '$completed dari ${visible.length}',
      chevron: true,
      onTap: onOpenLearn,
    );
  }

  /// Murajaah: jumlah ayat jatuh tempo (termasuk yang terlewat) dan surah
  /// mana. Belum pernah menghafal: ajakan memulai.
  Widget _murajaahRow(BuildContext context) {
    final all = SharedPreferencesService.allAyahMemorization();
    final due = dueForReview(all, now);
    final String subtitle;
    if (all.isEmpty) {
      subtitle = 'Pilih surah untuk mulai menghafal';
    } else if (due.isEmpty) {
      subtitle = 'Tidak ada yang jatuh tempo hari ini';
    } else {
      subtitle = '${_dueSummary(due)} · jatuh tempo';
    }
    return ListRow(
      leading: const SoftIconCircle(icon: SacredIcons.layers),
      title: all.isEmpty ? 'Mulai hafalan' : 'Murajaah hari ini',
      subtitle: subtitle,
      trailing: due.isEmpty ? null : StatusPill('${due.length} ayat'),
      chevron: due.isEmpty,
      onTap: onOpenHafalan,
    );
  }

  /// "An-Naba' 1–10" untuk surah pertama yang jatuh tempo, ditambah jumlah
  /// surah lain bila ada.
  static String _dueSummary(List<AyahMemorization> due) {
    final bySurah = <int, List<int>>{};
    for (final item in due) {
      bySurah.putIfAbsent(item.surah, () => []).add(item.ayah);
    }
    final first = bySurah.entries.first;
    final ayat = first.value..sort();
    final name = surahCatalog[first.key - 1].displayName;
    final range = ayat.first == ayat.last
        ? '${ayat.first}'
        : '${ayat.first}–${ayat.last}';
    final others = bySurah.length - 1;
    return others == 0 ? '$name $range' : '$name $range + $others surah';
  }
}

/// Strip salat 54: gradien langit periode sekarang, nama + jam salat
/// berikutnya, pill hitung mundur yang ikut berjalan. Luring: keadaan
/// sebenarnya, bukan jam contoh.
class _PrayerStrip extends StatefulWidget {
  const _PrayerStrip({
    required this.future,
    required this.now,
    required this.onTap,
  });

  final Future<PrayerDay?> future;
  final DateTime Function() now;
  final VoidCallback onTap;

  @override
  State<_PrayerStrip> createState() => _PrayerStripState();
}

class _PrayerStripState extends State<_PrayerStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Hitung mundur "dalam 2 j 25 m" diperbarui tiap 30 detik.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<PrayerDay?>(
        future: widget.future,
        builder: (context, snapshot) {
          final day = snapshot.data;
          if (day == null) {
            final loading = snapshot.connectionState != ConnectionState.done;
            return InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: SacredCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 38),
                  child: Row(
                    children: [
                      LineIcon(SacredIcons.sun, color: tokens.sec, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loading
                              ? 'Memuat jadwal salat…'
                              : 'Jadwal salat butuh koneksi internet.',
                          style: SacredText.cardNote.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final now = widget.now();
          final label = day.nextLabelAt(now);
          final time = day.timeFor(label);
          final countdown = time?.difference(now);
          final title = time == null ? label : '$label ${_clock(time)}';
          return Semantics(
            button: true,
            excludeSemantics: true,
            label:
                'Salat berikutnya $title'
                '${countdown == null ? '' : ', ${_remaining(countdown)} lagi'}',
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: SkyPeriod.fromHour(
                    now.hour,
                  ).gradientFor(Theme.of(context).brightness),
                ),
                child: _stripContent(
                  context,
                  title: title,
                  countdown: countdown != null && !countdown.isNegative
                      ? 'dalam ${_remaining(countdown)}'
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Isi strip: ikon, judul, pill. Di teks sangat besar pill pindah ke bawah
  /// judul supaya "Dzuhur 11:45" tidak dipecah per suku kata.
  Widget _stripContent(
    BuildContext context, {
    required String title,
    required String? countdown,
  }) {
    final large = _largeText(context);
    final icon = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: SacredArt.skyIconBg,
        shape: BoxShape.circle,
      ),
      child: const LineIcon(
        SacredIcons.sun,
        color: SacredArt.skyIcon,
        size: 19,
      ),
    );
    final label = Text(
      title,
      style: SacredText.stripTitle.copyWith(
        color: SacredArt.ink,
        shadows: const [
          Shadow(
            color: SacredArt.skyTextShadow,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
    final pill = countdown == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SacredArt.skyPill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              countdown,
              style: SacredText.stripPill.copyWith(color: SacredArt.ink),
            ),
          );
    if (large) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                if (pill != null) ...[const SizedBox(height: 4), pill],
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(child: label),
        if (pill != null) ...[const SizedBox(width: 8), pill],
      ],
    );
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  static String _remaining(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return hours == 0 ? '$minutes m' : '$hours j $minutes m';
  }
}
