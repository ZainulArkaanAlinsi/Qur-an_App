import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/screens/khatam_plan_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Beranda, mengikuti `docs/design/ios-redesign/html/Beranda.html` di folder
/// handoff: ukuran, jarak, dan warnanya diambil dari sana, bukan dikira-kira.
/// Mockup menentukan bentuk; seluruh angka yang tampil tetap dari perangkat.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuran,
    required this.onOpenLearn,
  });

  /// Pindah ke tab Qur'an.
  final VoidCallback onOpenQuran;

  /// Pindah ke tab Belajar.
  final VoidCallback onOpenLearn;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _data = _load();
  late Future<PrayerDay?> _prayer = _loadPrayer();
  final Future<Curriculum> _curriculum = CurriculumRepository.load();

  /// Data dari perangkat sendiri. Sengaja tidak menunggu jaringan supaya isi
  /// beranda tetap muncul saat luring.
  Future<_HomeData> _load() async {
    var juz = const <JuzBoundary>[];
    var names = const <String>[];
    try {
      juz = await JuzRepository.load();
      names = await SuraNamesRepository.load();
    } on Object {
      // Label juz dan nama Arab hilang; isi lainnya tetap tampil.
    }
    return _HomeData(juz: juz, arabicNames: names, verse: await _verseOfDay());
  }

  Future<PrayerDay?> _loadPrayer() async {
    try {
      return await PrayerService.fetch(
        city: SharedPreferencesService.getPrayerCity(),
        country: SharedPreferencesService.getPrayerCountry(),
      );
    } on Object {
      return null; // Luring: strip salat diganti keadaan jujur.
    }
  }

  /// Ayat hari ini diambil dari dataset yang sudah diverifikasi, dipilih
  /// berdasarkan tanggal supaya tetap sama sepanjang hari, dan selalu tampil
  /// bersama rujukannya. Tidak ada teks yang diketik ulang.
  Future<_VerseOfDay?> _verseOfDay() async {
    try {
      final today = DateTime.now();
      final seed = today.year * 1000 + _dayOfYear(today);
      final surah = surahCatalog[seed % surahCatalog.length];
      final ayah = seed % surah.ayahCount + 1;
      final arabic = await QuranTextRepository.instance.versesForSurah(
        surah.number,
      );
      String? translation;
      try {
        final list = await TranslationRepository.instance.forSurah(
          surah.number,
        );
        translation = list[ayah - 1];
      } on Object {
        translation = null;
      }
      return _VerseOfDay(
        surah: surah,
        ayah: ayah,
        arabic: arabic[ayah - 1],
        translation: translation,
      );
    } on Object {
      return null;
    }
  }

  static int _dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year)).inDays;

  void _openReader(SurahMeta surah, {int? verse}) => _push(
    ReaderScreen(
      surah: surah,
      initialVerse:
          verse ?? SharedPreferencesService.getLastReadVerse(surah.number),
    ),
  );

  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .then((_) {
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final lastReadNumber = SharedPreferencesService.getLastReadSurah();
    final surah = surahCatalog.firstWhere(
      (item) => item.number == lastReadNumber,
      orElse: () => surahCatalog.first,
    );
    final verse = SharedPreferencesService.getLastReadVerse(surah.number);
    final progress = ReadingProgressService.read();
    // Dihitung ulang tiap build: kembali dari layar latihan memanggil
    // setState, jadi angkanya tidak pernah basi.
    final dueToday = SharedPreferencesService.dueTodayCount();

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
            physics: const BouncingScrollPhysics(),
            // Ruang untuk tab bar mengambang supaya kartu terakhir tidak
            // tertutup kaca.
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              _Header(
                prayer: _prayer,
                onBookmark: () => _push(const BookmarkScreen()),
              ),
              const SizedBox(height: 12),
              const _Greeting(),
              const SizedBox(height: 16),
              _ContinueCard(
                surah: surah,
                verse: verse,
                juz: data?.juzOf(surah.number, verse),
                arabicName: data?.arabicNameOf(surah.number),
                onContinue: () => _openReader(surah, verse: verse),
                onListen: () async {
                  try {
                    await QuranAudioService.instance.toggle(
                      surah: surah.number,
                      ayah: verse,
                    );
                  } on Object {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Murottal belum dapat diputar.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _TargetAndStreak(progress: progress),
              // Urutan §E: setelah target datang murajaah hari ini. Kartunya
              // hanya muncul kalau memang ada yang jatuh tempo, supaya
              // beranda tidak penuh baris kosong.
              const SizedBox(height: 12),
              _ContinueLearning(
                future: _curriculum,
                onOpen: widget.onOpenLearn,
              ),
              if (dueToday > 0) ...[
                const SizedBox(height: 12),
                _MurajaahRow(
                  count: dueToday,
                  onTap: () => _push(const MemorizationScreen()),
                ),
              ],
              const SizedBox(height: 12),
              _Shortcuts(
                onQuran: widget.onOpenQuran,
                onLearn: widget.onOpenLearn,
                onBookmark: () => _push(const BookmarkScreen()),
                onKhatam: () => _push(const KhatamPlanScreen()),
              ),
              const SizedBox(height: 12),
              _PrayerStrip(
                future: _prayer,
                onTap: () => _push(const PrayerScreen()),
              ),
              const SizedBox(height: 12),
              _VerseCard(verse: data?.verse),
            ],
          ),
        );
      },
    );
  }
}

/// Tanggal Masehi dan Hijriah di kiri, bookmark dan profil di kanan.
class _Header extends StatelessWidget {
  const _Header({required this.prayer, required this.onBookmark});

  final Future<PrayerDay?> prayer;
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
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_days[now.weekday - 1]}, ${now.day} '
                  '${_months[now.month - 1]}',
                  style: SacredText.dateLine.copyWith(color: tokens.ink),
                ),
                FutureBuilder<PrayerDay?>(
                  future: prayer,
                  builder: (context, snapshot) {
                    final day = snapshot.data;
                    return Text(
                      day == null
                          ? 'Kalender Hijriah butuh koneksi'
                          : '${day.hijriDate} ${day.hijriMonth}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.dateSub.copyWith(color: tokens.sec),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SacredCircleButton(
            tooltip: 'Bookmark',
            onTap: onBookmark,
            background: tokens.surf,
            bordered: true,
            child: LineIcon(
              SacredIcons.bookmark,
              color: tokens.ink,
              size: 20,
              strokeWidth: SacredIcons.strokeBookmark,
            ),
          ),
          const SizedBox(width: 8),
          const _ProfileButton(),
        ],
      ),
    );
  }
}

/// Lingkaran 40 px seperti mockup, tetapi target sentuhnya 44 px agar nyaman
/// ditekan dan tidak bertabrakan dengan tombol sebelahnya.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ValueListenableBuilder<SyncAccount?>(
      valueListenable: AccountService.instance.account,
      builder: (context, account, _) {
        final initial = _initialOf(account?.name ?? account?.email);
        return SacredCircleButton(
          tooltip: account == null ? 'Belum masuk akun' : 'Akun tersambung',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                account == null
                    ? 'Masuk akun ada di tab Pengaturan.'
                    : 'Akun dan sinkronisasi ada di tab Pengaturan.',
              ),
            ),
          ),
          background: tokens.primary,
          child: initial == null
              ? LineIcon(
                  SacredIcons.sliders,
                  color: tokens.ctaInk,
                  size: 19,
                  strokeWidth: SacredIcons.strokeNav,
                )
              : Text(
                  initial,
                  style: SacredText.avatar.copyWith(color: tokens.ctaInk),
                ),
        );
      },
    );
  }

  static String? _initialOf(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.substring(0, 1).toUpperCase();
  }
}

/// Sapaan. Baris besarnya nama pengguna bila akun tersambung; kalau belum,
/// kalimat netral dengan gaya sama supaya tata letaknya tidak berubah.
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
                name == null || name.isEmpty ? 'Selamat membaca' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SacredText.greeting.copyWith(color: tokens.ink),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.juz,
    required this.arabicNames,
    required this.verse,
  });

  final List<JuzBoundary> juz;
  final List<String> arabicNames;
  final _VerseOfDay? verse;

  String? arabicNameOf(int surah) =>
      surah <= arabicNames.length ? arabicNames[surah - 1] : null;

  /// Juz tempat ayat berada, dari batas Tanzil yang sudah tervalidasi.
  int? juzOf(int surah, int ayah) {
    int? number;
    for (final boundary in juz) {
      if (boundary.surah < surah ||
          (boundary.surah == surah && boundary.verse <= ayah)) {
        number = boundary.number;
      }
    }
    return number;
  }
}

class _VerseOfDay {
  const _VerseOfDay({
    required this.surah,
    required this.ayah,
    required this.arabic,
    required this.translation,
  });

  final SurahMeta surah;
  final int ayah;
  final String arabic;
  final String? translation;
}

/// Kartu hero "Lanjutkan membaca".
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.surah,
    required this.verse,
    required this.juz,
    required this.arabicName,
    required this.onContinue,
    required this.onListen,
  });

  final SurahMeta surah;
  final int verse;
  final int? juz;
  final String? arabicName;
  final VoidCallback onContinue;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final fraction = (verse / surah.ayahCount).clamp(0.0, 1.0);
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 86,
                        height: 110,
                        child: _MihrabPlate(arabicName: arabicName),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANJUTKAN MEMBACA',
                              style: SacredText.eyebrow.copyWith(
                                color: tokens.artInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              surah.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.heroTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ayat $verse dari ${surah.ayahCount}'
                              '${juz == null ? '' : ' · Juz $juz'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.dateSub.copyWith(
                                color: Colors.white.withValues(alpha: .82),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: fraction,
                                      minHeight: 5,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: .18,
                                      ),
                                      valueColor: AlwaysStoppedAnimation(
                                        tokens.artInk,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(fraction * 100).round()}%',
                                  style: SacredText.percent.copyWith(
                                    color: tokens.artInk,
                                  ),
                                ),
                              ],
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
                        child: _HeroButton(
                          label: 'Lanjutkan',
                          onTap: onContinue,
                          background: tokens.artInk,
                          foreground: const Color(0xFF1F1A05),
                          icon: const LineIcon(
                            SacredIcons.play,
                            color: Color(0xFF1F1A05),
                            size: 15,
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _HeroButton(
                          label: 'Dengarkan',
                          onTap: onListen,
                          background: Colors.white.withValues(alpha: .12),
                          foreground: Colors.white,
                          outlined: true,
                          icon: const LineIcon(
                            SacredIcons.headphones,
                            color: Colors.white,
                            size: 18,
                            strokeWidth: SacredIcons.strokeNav,
                          ),
                        ),
                      ),
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

/// Bingkai mihrab kecil berisi nama Arab surah, seperti di mockup.
class _MihrabPlate extends StatelessWidget {
  const _MihrabPlate({required this.arabicName});

  final String? arabicName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return CustomPaint(
      foregroundPainter: _MihrabOutline(color: tokens.artInk),
      child: ClipPath(
        clipper: const MihrabClipper(radius: 14),
        child: ColoredBox(
          color: const Color(0x38000000),
          child: Align(
            alignment: const Alignment(0, .35),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                arabicName ?? '',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: 22,
                  height: 40 / 22,
                  color: tokens.artInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MihrabOutline extends CustomPainter {
  const _MihrabOutline({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 3.0;
    if (size.width <= inset * 2 || size.height <= inset * 2) return;
    final path = MihrabClipper.pathFor(
      Size(size.width - inset * 2, size.height - inset * 2),
      radius: 11,
    ).shift(const Offset(inset, inset));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color.withValues(alpha: .85),
    );
  }

  @override
  bool shouldRepaint(_MihrabOutline old) => old.color != color;
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Widget icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(23),
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: EdgeInsets.symmetric(horizontal: outlined ? 18 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(23),
        border: outlined
            ? Border.all(color: Colors.white.withValues(alpha: .2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (outlined ? SacredText.heroAction : SacredText.heroCta)
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TargetAndStreak extends StatelessWidget {
  const _TargetAndStreak({required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _TargetCard(progress: progress)),
            const SizedBox(width: 12),
            Expanded(child: _StreakCard(progress: progress)),
          ],
        ),
      ),
    );
  }
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
        : (progress.todaySeconds / progress.targetSeconds).clamp(0.0, 1.0);

    return SoftCard(
      shadowed: true,
      // Beranda memakai padding 14, lebih rapat dari bawaan 16.
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target hari ini',
            style: SacredText.cardLabel.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: tokens.surf2,
                      valueColor: AlwaysStoppedAnimation(tokens.primaryText),
                    ),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: SacredText.ringLabel.copyWith(color: tokens.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                      overflow: TextOverflow.ellipsis,
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
  const _StreakCard({required this.progress});

  final ReadingProgress progress;

  /// Huruf hari Indonesia, Senin di indeks 0 seperti `DateTime.weekday`.
  static const _letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  /// Pekan berjalan Senin–Minggu, sesuai mockup. Hari yang belum datang
  /// dibiarkan kosong, bukan ditandai gagal.
  static List<_Day> _week() {
    final now = DateTime.now();
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
    final week = _week();
    return SoftCard(
      shadowed: true,
      // Beranda memakai padding 14, lebih rapat dari bawaan 16.
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Istiqamah',
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${progress.currentStreak}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.metric.copyWith(color: tokens.ink),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'hari',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.metricUnit.copyWith(color: tokens.sec),
                ),
              ),
              const Spacer(),
              if (progress.pendingToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.goldSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'MENUNGGU',
                    style: SacredText.chip.copyWith(color: tokens.goldText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in week) _DayDot(day: day)],
          ),
        ],
      ),
    );
  }
}

/// Satu hari pada baris pekan istiqamah.
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
        : 'belum tercapai';
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
                // Hari ini yang belum memenuhi target: lingkaran putus-putus.
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
      ..strokeCap = StrokeCap.round
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

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({
    required this.onQuran,
    required this.onLearn,
    required this.onBookmark,
    required this.onKhatam,
  });

  final VoidCallback onQuran;
  final VoidCallback onLearn;
  final VoidCallback onBookmark;
  final VoidCallback onKhatam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ShortcutChip(
            paths: SacredIcons.book,
            label: 'Surah',
            onTap: onQuran,
          ),
          const SizedBox(width: 8),
          // Belajar adalah tujuan utama revisi v2, jadi ia punya pintasan
          // sendiri dan tidak lagi hanya tersembunyi di dalam tab Progres.
          _ShortcutChip(
            paths: SacredIcons.palette,
            label: 'Belajar',
            onTap: onLearn,
          ),
          const SizedBox(width: 8),
          _ShortcutChip(
            paths: SacredIcons.bookmark,
            label: 'Bookmark',
            onTap: onBookmark,
          ),
          const SizedBox(width: 8),
          _ShortcutChip(
            paths: SacredIcons.checkCircle,
            label: 'Khatam',
            onTap: onKhatam,
          ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.paths,
    required this.label,
    required this.onTap,
  });

  final List<String> paths;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: tokens.surf,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.sep),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F00281C),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LineIcon(
                    paths,
                    color: tokens.primaryText,
                    size: 19,
                    strokeWidth: SacredIcons.strokeAction,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.chipLabel.copyWith(color: tokens.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strip salat: nama dan jam salat berikutnya, plus hitung mundur. Saat jadwal
/// tidak bisa dimuat, yang tampil keadaan sebenarnya, bukan jam contoh.
class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.future, required this.onTap});

  final Future<PrayerDay?> future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<PrayerDay?>(
        future: future,
        builder: (context, snapshot) {
          final day = snapshot.data;
          if (day == null) {
            final loading = snapshot.connectionState != ConnectionState.done;
            return Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: tokens.surf,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.sep),
              ),
              child: Row(
                children: [
                  LineIcon(
                    SacredIcons.sun,
                    color: tokens.sec,
                    size: 20,
                    strokeWidth: SacredIcons.strokeAction,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loading
                          ? 'Memuat jadwal salat…'
                          : 'Jadwal salat butuh koneksi internet.',
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ),
                ],
              ),
            );
          }

          final label = day.nextLabel;
          final time = day.timeFor(label);
          final countdown = time?.difference(DateTime.now());
          return Semantics(
            button: true,
            label: 'Jadwal salat, $label',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0B3F48),
                        Color(0xFF2E7078),
                        Color(0xFFB7A383),
                        Color(0xFFF2C98A),
                      ],
                      stops: [0, .44, .76, 1],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          shape: BoxShape.circle,
                        ),
                        child: const LineIcon(
                          SacredIcons.sun,
                          color: Color(0xFFFFF1C9),
                          size: 20,
                          strokeWidth: SacredIcons.strokeAction,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          time == null ? label : '$label ${_clock(time)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SacredText.stripTitle.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0x4D000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (countdown != null && !countdown.isNegative) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .28),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'dalam ${_remaining(countdown)}',
                            style: SacredText.stripPill.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});

  final _VerseOfDay? verse;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final data = verse;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.goldSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AYAT HARI INI',
              style: SacredText.eyebrow.copyWith(color: tokens.goldText),
            ),
            const SizedBox(height: 8),
            if (data == null)
              Text(
                'Ayat hari ini belum dapat dimuat.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              )
            else ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  data.arabic,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: 28,
                    height: 52 / 28,
                    color: tokens.ink,
                  ),
                ),
              ),
              if (data.translation != null) ...[
                const SizedBox(height: 8),
                Text(
                  '“${data.translation}”',
                  style: SacredText.verseTranslation.copyWith(
                    color: tokens.ink,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'QS. ${data.surah.displayName} '
                '${data.surah.number}:${data.ayah}',
                style: SacredText.cardLabel.copyWith(color: tokens.sec),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baris "murajaah hari ini". Hanya tampil bila ada yang jatuh tempo.
class _MurajaahRow extends StatelessWidget {
  const _MurajaahRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: 'Murajaah hari ini, $count ayat',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.surf,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.sep),
            ),
            child: Row(
              children: [
                LineIcon(
                  SacredIcons.repeat,
                  color: tokens.primaryText,
                  size: 20,
                  strokeWidth: SacredIcons.strokeAction,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Murajaah hari ini',
                        style: SacredText.listName.copyWith(color: tokens.ink),
                      ),
                      Text(
                        '$count ayat menunggu diulang.',
                        style: SacredText.cardNote.copyWith(color: tokens.sec),
                      ),
                    ],
                  ),
                ),
                LineIcon(
                  SacredIcons.chevronRight,
                  color: tokens.sec,
                  size: 18,
                  strokeWidth: 2.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris "lanjutkan belajar". Menghilang kalau tidak ada materi yang boleh
/// tampil, supaya beranda tidak memuat baris yang tidak bisa dibuka.
class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning({required this.future, required this.onOpen});

  final Future<Curriculum> future;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return FutureBuilder<Curriculum>(
      future: future,
      builder: (context, snapshot) {
        final curriculum = snapshot.data;
        if (curriculum == null) return const SizedBox.shrink();
        final visible = curriculum.visible(includeDrafts: showDraftLessons);
        if (visible.isEmpty) return const SizedBox.shrink();

        final done = SharedPreferencesService.getCompletedLessons();
        final next = curriculum.nextAfter(
          done,
          includeDrafts: showDraftLessons,
        );
        final completed = curriculum.completedCount(
          done,
          includeDrafts: showDraftLessons,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: next == null
                ? 'Belajar, semua tahap selesai'
                : 'Lanjutkan belajar, tahap ${next.level} ${next.title}',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onOpen,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: tokens.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.sep),
                ),
                child: Row(
                  children: [
                    LineIcon(
                      SacredIcons.book,
                      color: tokens.primaryText,
                      size: 20,
                      strokeWidth: SacredIcons.strokeAction,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lanjutkan belajar',
                            style: SacredText.listName.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                          Text(
                            next == null
                                ? 'Semua $completed tahap sudah selesai.'
                                : 'Tahap ${next.level}: ${next.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.cardNote.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$completed/${visible.length}',
                      style: SacredText.chip.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
