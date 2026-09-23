import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/khatam_plan_screen.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Beranda edisi iOS. Urutannya mengikuti panduan: lanjut baca, target hari
/// ini, istiqamah, pintasan, strip salat, lalu ayat hari ini.
///
/// Semua angka berasal dari data nyata perangkat; tidak ada angka contoh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenQuran});

  /// Pindah ke tab Qur'an.
  final VoidCallback onOpenQuran;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _data = _load();
  late Future<PrayerDay?> _prayer = _loadPrayer();

  /// Data dari perangkat sendiri. Sengaja tidak menunggu jaringan supaya isi
  /// beranda tetap muncul saat luring.
  Future<_HomeData> _load() async {
    List<JuzBoundary> juz;
    try {
      juz = await JuzRepository.load();
    } on Object {
      juz = const [];
    }
    return _HomeData(juz: juz, verse: await _verseOfDay());
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

  void _openReader(SurahMeta surah, {int? verse}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(
              surah: surah,
              initialVerse:
                  verse ??
                  SharedPreferencesService.getLastReadVerse(surah.number),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final lastReadNumber = SharedPreferencesService.getLastReadSurah();
    final surah = surahCatalog.firstWhere(
      (item) => item.number == lastReadNumber,
      orElse: () => surahCatalog.first,
    );
    final verse = SharedPreferencesService.getLastReadVerse(surah.number);
    final progress = ReadingProgressService.read();

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            children: [
              _PrayerBuilder(
                future: _prayer,
                builder: (day, loading) => _Header(hijri: day),
              ),
              const SizedBox(height: 10),
              Text(
                'Assalamu’alaikum,',
                style: SacredText.body.copyWith(color: tokens.sec),
              ),
              Text(
                'Selamat membaca',
                style: SacredText.greeting.copyWith(color: tokens.ink),
              ),
              const SizedBox(height: 16),
              _ContinueCard(
                surah: surah,
                verse: verse,
                juz: data?.juzOf(surah.number, verse),
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
              const SizedBox(height: 12),
              _Shortcuts(
                onQuran: widget.onOpenQuran,
                onBookmark: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BookmarkScreen(),
                  ),
                ),
                onKhatam: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KhatamPlanScreen(),
                  ),
                ),
                onLearn: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Belajar')),
                      body: const SafeArea(child: LearnScreen()),
                    ),
                  ),
                ),
                onMemorize: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemorizationScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PrayerBuilder(
                future: _prayer,
                builder: (day, loading) =>
                    _PrayerStrip(day: day, loading: loading),
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

/// Menyalurkan hasil jadwal salat ke dua tempat: tanggal Hijriah di kepala
/// halaman dan strip salat di bawah.
class _PrayerBuilder extends StatelessWidget {
  const _PrayerBuilder({required this.future, required this.builder});

  final Future<PrayerDay?> future;
  final Widget Function(PrayerDay? day, bool loading) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<PrayerDay?>(
    future: future,
    builder: (context, snapshot) => builder(
      snapshot.data,
      snapshot.connectionState != ConnectionState.done,
    ),
  );
}

class _HomeData {
  const _HomeData({required this.juz, required this.verse});

  final List<JuzBoundary> juz;
  final _VerseOfDay? verse;

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

class _Header extends StatelessWidget {
  const _Header({required this.hijri});

  final PrayerDay? hijri;

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
    final day = hijri;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_days[now.weekday - 1]}, ${now.day} '
                '${_months[now.month - 1]}',
                style: SacredText.headline.copyWith(color: tokens.ink),
              ),
              Text(
                day == null
                    ? 'Kalender Hijriah butuh koneksi'
                    : '${day.hijriDate} ${day.hijriMonth}',
                style: SacredText.footnote.copyWith(color: tokens.sec),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bookmark',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BookmarkScreen()),
          ),
          icon: Icon(Icons.bookmark_border_rounded, color: tokens.ink),
        ),
      ],
    );
  }
}

/// Kartu hero "Lanjutkan membaca".
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.surah,
    required this.verse,
    required this.juz,
    required this.onContinue,
    required this.onListen,
  });

  final SurahMeta surah;
  final int verse;
  final int? juz;
  final VoidCallback onContinue;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final fraction = (verse / surah.ayahCount).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        color: tokens.art,
        child: Stack(
          children: [
            const Positioned.fill(child: GeometricPattern(opacity: .10)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 78,
                        height: 104,
                        child: MihrabFrame(
                          background: tokens.art,
                          child: RosetteBadge(
                            label: '${surah.number}',
                            size: 40,
                            textColor: tokens.artInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LANJUTKAN MEMBACA',
                              style: SacredText.eyebrow.copyWith(
                                color: tokens.artInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              surah.displayName,
                              style: SacredText.cardTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Ayat $verse dari ${surah.ayahCount}'
                              '${juz == null ? '' : ' · Juz $juz'}',
                              style: SacredText.footnote.copyWith(
                                color: Colors.white.withValues(alpha: .82),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: fraction,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: .22,
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
                                  style: SacredText.footnote.copyWith(
                                    color: tokens.artInk,
                                    fontWeight: FontWeight.w800,
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
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.artInk,
                            foregroundColor: const Color(0xFF1F1A05),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: onContinue,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Lanjutkan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .5),
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: onListen,
                          icon: const Icon(Icons.headphones_rounded),
                          label: const Text('Dengarkan'),
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

class _TargetAndStreak extends StatelessWidget {
  const _TargetAndStreak({required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final minutes = (progress.todaySeconds / 60).floor();
    final target = (progress.targetSeconds / 60).round();
    final remaining = (progress.remainingSeconds / 60).ceil();
    // Target bisa disetel 0; jangan biarkan pembagian itu jadi NaN.
    final fraction = progress.targetSeconds <= 0
        ? 1.0
        : (progress.todaySeconds / progress.targetSeconds).clamp(0.0, 1.0);

    // IntrinsicHeight menyamakan tinggi kedua kartu; tanpa itu `stretch` di
    // dalam daftar yang bisa digulir meminta tinggi tak terbatas.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Panel(
              title: 'Target hari ini',
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: fraction,
                          strokeWidth: 6,
                          backgroundColor: tokens.surf2,
                          valueColor: AlwaysStoppedAnimation(tokens.primary),
                        ),
                        Text(
                          '${(fraction * 100).round()}%',
                          style: SacredText.footnote.copyWith(
                            color: tokens.ink,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$minutes/$target mnt',
                          style: SacredText.headline.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        Text(
                          progress.completedToday
                              ? 'Target tercapai'
                              : '$remaining mnt lagi',
                          style: SacredText.footnote.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Panel(
              title: 'Istiqamah',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${progress.currentStreak}',
                        style: SacredText.headline.copyWith(
                          color: tokens.ink,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hari',
                        style: SacredText.footnote.copyWith(color: tokens.sec),
                      ),
                      const Spacer(),
                      if (progress.pendingToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.goldSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'MENUNGGU',
                            style: SacredText.eyebrow.copyWith(
                              color: tokens.goldText,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < progress.recentDays.length; i++)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: progress.recentDays[i]
                                ? tokens.gold
                                : tokens.surf2,
                            border: i == progress.recentDays.length - 1
                                ? Border.all(color: tokens.gold, width: 1.4)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SacredText.footnote.copyWith(color: tokens.sec)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({
    required this.onQuran,
    required this.onBookmark,
    required this.onKhatam,
    required this.onLearn,
    required this.onMemorize,
  });

  final VoidCallback onQuran;
  final VoidCallback onBookmark;
  final VoidCallback onKhatam;
  final VoidCallback onLearn;
  final VoidCallback onMemorize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _ShortcutChip(
              icon: Icons.menu_book_outlined,
              label: 'Surah',
              onTap: onQuran,
            ),
            const SizedBox(width: 10),
            _ShortcutChip(
              icon: Icons.bookmark_border_rounded,
              label: 'Bookmark',
              onTap: onBookmark,
            ),
            const SizedBox(width: 10),
            _ShortcutChip(
              icon: Icons.check_circle_outline_rounded,
              label: 'Khatam',
              onTap: onKhatam,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ShortcutChip(
              icon: Icons.school_outlined,
              label: 'Belajar',
              onTap: onLearn,
            ),
            const SizedBox(width: 10),
            _ShortcutChip(
              icon: Icons.psychology_outlined,
              label: 'Hafalan',
              onTap: onMemorize,
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.sep),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: tokens.primaryText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.footnote.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.day, required this.loading});

  final PrayerDay? day;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final period = SkyPeriod.fromHour(DateTime.now().hour);
    final prayer = day;
    if (prayer == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.sep),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: tokens.sec),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading
                    ? 'Memuat jadwal salat…'
                    : 'Jadwal salat butuh koneksi internet.',
                style: SacredText.footnote.copyWith(color: tokens.sec),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PrayerScreen())),
      child: SkyStrip(
        period: period,
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                prayer.nextLabel,
                style: SacredText.headline.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});

  final _VerseOfDay? verse;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final data = verse;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AYAT HARI INI',
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          const SizedBox(height: 10),
          if (data == null)
            Text(
              'Ayat hari ini belum dapat dimuat.',
              style: SacredText.footnote.copyWith(color: tokens.sec),
            )
          else ...[
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.arabic,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: SharedPreferencesService.getArabicFontSize(),
                  height: SharedPreferencesService.getArabicLineHeight(),
                  color: tokens.ink,
                ),
              ),
            ),
            if (data.translation != null) ...[
              const SizedBox(height: 10),
              Text(
                data.translation!,
                style: SacredText.body.copyWith(color: tokens.ink),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'QS ${data.surah.displayName} : ${data.ayah} · Teks Tanzil, '
              'terjemahan Kemenag via Tanzil',
              style: SacredText.footnote.copyWith(color: tokens.sec),
            ),
          ],
        ],
      ),
    );
  }
}
