import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_heatmap.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/khatam/domain/juz_coverage.dart';
import 'package:quran_app_2025/screens/khatam_plan_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Rentang yang ditampilkan heatmap.
enum _Span {
  minggu('Minggu', 7),
  bulan('Bulan', 35),
  tahun('Tahun', 364);

  const _Span(this.label, this.days);
  final String label;
  final int days;
}

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi isinya.
const _bottomInset = 132.0;

/// Layar Progres, mengikuti nilai di `Progres.html`.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  _Span _span = _Span.bulan;
  late Future<_KhatamData> _khatam = _loadKhatam();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<_KhatamData> _loadKhatam() async => _KhatamData(
    juz: await JuzRepository.load(),
    pages: await PageRepository.load(),
  );

  /// Satu sel per hari, memakai target yang berlaku pada hari itu.
  List<HeatCell> _cells() {
    final now = DateTime.now();
    final today = ReadingProgressService.localDate(now);
    final cells = <HeatCell>[];
    for (var back = _span.days - 1; back >= 0; back--) {
      final day = DateTime(now.year, now.month, now.day - back);
      final key = ReadingProgressService.localDate(day);
      cells.add(
        HeatCell(
          date: day,
          seconds: SharedPreferencesService.getReadingSeconds(key),
          targetSeconds: SharedPreferencesService.getTargetForDate(key),
          isToday: key == today,
        ),
      );
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final progress = ReadingProgressService.read();

    // Layar ini juga dipakai tanpa Scaffold, sedangkan segmented control dan
    // tombolnya memakai InkWell yang butuh Material.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: _bottomInset),
        children: [
          const LargeTitle(
            'Progres',
            subtitle: 'Catatan kecil untuk menemani kebiasaan baikmu.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedPill<_Span>(
              segments: {for (final span in _Span.values) span: span.label},
              value: _span,
              onChanged: (value) => setState(() => _span = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StreakCard(
                  progress: progress,
                  cells: _cells(),
                  // Setahun penuh tidak muat pada tujuh kolom; pakai kolom
                  // sebanyak minggunya supaya selnya tetap persegi.
                  columns: _span == _Span.tahun ? 26 : 7,
                ),
                const SizedBox(height: 12),
                _KhatamCard(
                  data: _khatam,
                  onRetry: () => setState(() => _khatam = _loadKhatam()),
                  onOpenList: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const KhatamPlanScreen(),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(() {});
                      }),
                  onOpenJuz: (boundary) => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReaderScreen(
                            surah: surahCatalog[boundary.surah - 1],
                            initialVerse: boundary.verse,
                          ),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(() {});
                      }),
                ),
                // Belajar dan Hafalan sekarang punya tabnya sendiri, jadi
                // pintasannya tidak lagi menumpang di layar ini.
                const SizedBox(height: 12),
                Text(
                  'Waktu ini adalah perkiraan saat pembaca aktif di depan layar, '
                  'bukan ukuran ibadah.',
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu putih bersudut 24 dengan bayangan setipis mockup-nya.
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.sep),
      ),
      child: child,
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.progress,
    required this.cells,
    required this.columns,
  });

  final ReadingProgress progress;
  final List<HeatCell> cells;
  final int columns;

  /// "1 j 05 m" seperti kolom kanan pada mockup; di bawah sejam cukup menit.
  static String _hoursMinutes(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours == 0
        ? '$minutes m'
        : '$hours j ${minutes.toString().padLeft(2, '0')} m';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final remaining = (progress.remainingSeconds / 60).ceil();
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ISTIQAMAH',
                      style: SacredText.eyebrow.copyWith(
                        color: tokens.goldText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${progress.currentStreak} '),
                          TextSpan(
                            text: 'hari beruntun',
                            style: SacredText.statUnit.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.statNumber.copyWith(color: tokens.ink),
                    ),
                    Text(
                      'Terbaik ${progress.longestStreak} hari',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Fleksibel: pada teks besar kolom kanan ini yang paling mudah
              // meluber keluar kartu.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Baca ${_hoursMinutes(progress.totalSeconds)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: SacredText.statSide.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      // Jujur: durasi murottal memang belum pernah dihitung,
                      // jadi angkanya tidak boleh dikarang.
                      'Dengar belum dicatat',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SacredHeatmap(cells: cells, columns: columns),
          const SizedBox(height: 4),
          Text(
            progress.completedToday
                ? 'Target hari ini tercapai.'
                : 'Hari ini $remaining mnt lagi.',
            style: SacredText.cardNote.copyWith(color: tokens.primaryText),
          ),
        ],
      ),
    );
  }
}

class _KhatamData {
  const _KhatamData({required this.juz, required this.pages});

  final List<JuzBoundary> juz;
  final List<PageBoundary> pages;
}

/// Grid 30 juz. Satu juz hanya hijau bila seluruh surah yang menyinggungnya
/// sudah ditandai selesai, dan aturan itu ditulis apa adanya di kartunya.
class _KhatamCard extends StatelessWidget {
  const _KhatamCard({
    required this.data,
    required this.onRetry,
    required this.onOpenList,
    required this.onOpenJuz,
  });

  final Future<_KhatamData> data;
  final VoidCallback onRetry;
  final VoidCallback onOpenList;
  final ValueChanged<JuzBoundary> onOpenJuz;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return _SoftCard(
      child: FutureBuilder<_KhatamData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang batas juz'),
              ),
            );
          }
          if (!snapshot.hasData) {
            // Teks diam, bukan indikator berputar: pemuatannya dari aset
            // bawaan dan selesai seketika, sementara animasi tanpa akhir
            // membuat layar ini tidak pernah "tenang".
            return Text(
              'Memuat batas juz…',
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            );
          }
          final boundaries = snapshot.data!.juz;
          final pages = snapshot.data!.pages;
          final completedSurahs = SharedPreferencesService.getCompletedSurahs();
          final done = JuzCoverage.completeJuz(completedSurahs, boundaries);
          final next = JuzCoverage.nextIncomplete(completedSurahs, boundaries);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RENCANA KHATAM',
                style: SacredText.eyebrow.copyWith(color: tokens.goldText),
              ),
              const SizedBox(height: 2),
              Text(
                'Juz ${done.length} dari 30 selesai',
                style: SacredText.khatamTitle.copyWith(color: tokens.ink),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 10;
                  const gap = 5.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var number = 1; number <= 30; number++)
                        SizedBox(
                          width: width,
                          height: 30,
                          child: _JuzTile(
                            number: number,
                            complete: done.contains(number),
                            isNext: number == next,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (next != null)
                _NextJuzRow(
                  juz: next,
                  range: JuzCoverage.pageRangeFor(next, boundaries, pages),
                  onTap: () => onOpenJuz(boundaries[next - 1]),
                )
              else
                Text(
                  'Seluruh 30 juz sudah ditandai selesai.',
                  style: SacredText.cardNote.copyWith(
                    color: tokens.primaryText,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Aplikasi mencatat surah yang selesai, bukan tiap ayat. Karena '
                'itu satu juz baru hijau setelah semua surah yang menyentuhnya '
                'ditandai selesai — ${completedSurahs.length} dari '
                '${surahCatalog.length} surah sejauh ini.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpenList,
                icon: LineIcon(
                  SacredIcons.checkCircle,
                  color: tokens.primaryText,
                  size: 18,
                  strokeWidth: SacredIcons.strokeAction,
                ),
                label: const Text('Tandai surah selesai'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Baris "lanjut di juz ini". Rentang halamannya dihitung dari metadata
/// Tanzil; perkiraan lama membaca sengaja tidak ditampilkan karena tidak
/// pernah diukur.
class _NextJuzRow extends StatelessWidget {
  const _NextJuzRow({
    required this.juz,
    required this.range,
    required this.onTap,
  });

  final int juz;
  final (int, int) range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Lanjut di Juz $juz, halaman ${range.$1} sampai ${range.$2}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.cta,
                  shape: BoxShape.circle,
                ),
                child: LineIcon(
                  SacredIcons.play,
                  color: tokens.ctaInk,
                  size: 15,
                  filled: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lanjut di Juz $juz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.statSide.copyWith(color: tokens.ink),
                    ),
                    Text(
                      'Halaman ${range.$1}–${range.$2}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.listMeta.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
    );
  }
}

class _JuzTile extends StatelessWidget {
  const _JuzTile({
    required this.number,
    required this.complete,
    required this.isNext,
  });

  final int number;
  final bool complete;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final state = complete
        ? 'selesai'
        : isNext
        ? 'berikutnya'
        : 'belum';
    // `container` + `excludeSemantics` di simpul yang sama: membungkus
    // ExcludeSemantics justru membuat labelnya ikut hilang.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Juz $number: $state',
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: complete
              ? tokens.toggleOn
              : isNext
              ? tokens.goldSoft
              : tokens.surf2,
          borderRadius: BorderRadius.circular(9),
          border: isNext ? Border.all(color: tokens.gold, width: 1.5) : null,
        ),
        child: Text(
          '$number',
          style: SacredText.khatamCell.copyWith(
            color: complete
                ? tokens.ctaInk
                : isNext
                ? tokens.goldText
                : tokens.sec,
          ),
        ),
      ),
    );
  }
}
