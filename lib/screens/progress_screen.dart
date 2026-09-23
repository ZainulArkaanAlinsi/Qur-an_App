import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_heatmap.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/khatam/domain/juz_coverage.dart';
import 'package:quran_app_2025/screens/khatam_plan_screen.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
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

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  _Span _span = _Span.minggu;
  late Future<List<JuzBoundary>> _juz = JuzRepository.load();

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
    final remaining = (progress.remainingSeconds / 60).ceil();

    // Layar ini juga dipakai tanpa Scaffold (mis. di dalam Profil), sedangkan
    // segmented control dan tombolnya memakai InkWell yang butuh Material.
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
                _Card(
                  title: 'Istiqamah',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${progress.currentStreak}',
                            style: SacredText.cardTitle.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Fleksibel supaya tidak meluber pada teks besar.
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'hari beruntun',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.footnote.copyWith(
                                  color: tokens.sec,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Terbaik ${progress.longestStreak} hari',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: SacredText.footnote.copyWith(
                                  color: tokens.sec,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // IntrinsicHeight menyamakan tinggi dua kotak; `stretch`
                      // sendirian di dalam daftar meminta tinggi tak terbatas.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _Metric(
                                label: 'Baca',
                                value: '${progress.totalSeconds ~/ 60} mnt',
                                note: 'tercatat di perangkat ini',
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: _Metric(
                                label: 'Dengar',
                                value: 'Belum dicatat',
                                // Jujur: durasi murottal memang belum pernah
                                // dihitung, jadi angkanya tidak boleh dikarang.
                                note: 'waktu murottal belum dihitung',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SacredHeatmap(
                        cells: _cells(),
                        cellSize: _span == _Span.tahun ? 10 : 22,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        progress.completedToday
                            ? 'Target hari ini tercapai.'
                            : 'Hari ini $remaining mnt lagi.',
                        style: SacredText.footnote.copyWith(
                          color: tokens.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _KhatamCard(
                  juz: _juz,
                  onRetry: () => setState(() => _juz = JuzRepository.load()),
                ),
                const SizedBox(height: 12),
                // Beranda hanya memuat tiga pintasan seperti acuan desain,
                // jadi Belajar dan Hafalan dibuka dari sini.
                _MenuRow(
                  paths: SacredIcons.book,
                  title: 'Belajar tajwid',
                  subtitle: 'Hukum bacaan beserta contoh ayatnya.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LearnScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _MenuRow(
                  paths: SacredIcons.checkCircle,
                  title: 'Hafalan',
                  subtitle: 'Tandai surah yang sedang dihafal.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemorizationScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Waktu ini adalah perkiraan saat pembaca aktif di depan layar, '
                  'bukan ukuran ibadah.',
                  style: SacredText.footnote.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: SacredText.eyebrow.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SacredText.footnote.copyWith(color: tokens.sec)),
          const SizedBox(height: 2),
          Text(value, style: SacredText.headline.copyWith(color: tokens.ink)),
          Text(
            note,
            style: SacredText.footnote.copyWith(
              color: tokens.sec,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid 30 juz. Satu juz hanya hijau bila seluruh surah yang menyinggungnya
/// sudah ditandai selesai, dan aturan itu ditulis apa adanya di kartunya.
class _KhatamCard extends StatelessWidget {
  const _KhatamCard({required this.juz, required this.onRetry});

  final Future<List<JuzBoundary>> juz;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return _Card(
      title: 'Rencana khatam',
      child: FutureBuilder<List<JuzBoundary>>(
        future: juz,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(CupertinoIcons.refresh),
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
              style: SacredText.footnote.copyWith(color: tokens.sec),
            );
          }
          final boundaries = snapshot.data!;
          final completedSurahs = SharedPreferencesService.getCompletedSurahs();
          final done = JuzCoverage.completeJuz(completedSurahs, boundaries);
          final next = JuzCoverage.nextIncomplete(completedSurahs, boundaries);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var number = 1; number <= 30; number++)
                    _JuzTile(
                      number: number,
                      complete: done.contains(number),
                      isNext: number == next,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                next == null
                    ? 'Seluruh 30 juz sudah ditandai selesai.'
                    : 'Juz berikutnya: Juz $next.',
                style: SacredText.footnote.copyWith(
                  color: tokens.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aplikasi mencatat surah yang selesai, bukan tiap ayat. Karena '
                'itu satu juz baru hijau setelah semua surah yang menyentuhnya '
                'ditandai selesai — ${completedSurahs.length} dari '
                '${surahCatalog.length} surah sejauh ini.',
                style: SacredText.footnote.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KhatamPlanScreen(),
                  ),
                ),
                icon: const Icon(CupertinoIcons.checkmark_circle, size: 18),
                label: const Text('Tandai surah selesai'),
              ),
            ],
          );
        },
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
        width: 42,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: complete ? tokens.primary : tokens.fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNext ? tokens.gold : tokens.sep,
            width: isNext ? 1.8 : 1,
          ),
        ),
        child: Text(
          '$number',
          style: SacredText.footnote.copyWith(
            color: complete ? tokens.ctaInk : tokens.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Baris menu ke layar lain, dengan target sentuh penuh selebar kartunya.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.paths,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<String> paths;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.sep),
        ),
        child: Row(
          children: [
            LineIcon(
              paths,
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
                    title,
                    style: SacredText.headline.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 18, color: tokens.sec),
          ],
        ),
      ),
    );
  }
}
