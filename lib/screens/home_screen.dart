import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_shell.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuran,
    required this.onOpenQibla,
  });
  final VoidCallback onOpenQuran;
  final VoidCallback onOpenQibla;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final lastRead = SharedPreferencesService.getLastReadSurah();
    final surah = surahCatalog.firstWhere(
      (item) => item.number == lastRead,
      orElse: () => surahCatalog.first,
    );
    final progress = ReadingProgressService.read();
    final completion = (progress.todaySeconds / progress.targetSeconds).clamp(
      0.0,
      1.0,
    );
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SacredTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: SacredTheme.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assalamu’alaikum',
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        'Ruang tilawahmu',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => openBookmarks(context),
                  tooltip: 'Bookmark',
                  icon: const Icon(Icons.bookmark_outline_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _ContinueCard(
              surah: surah,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      surah: surah,
                      initialVerse: SharedPreferencesService.getLastReadVerse(
                        surah.number,
                      ),
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Ritme hari ini',
              trailing: '${progress.todaySeconds ~/ 60} menit',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ProgressRing(value: completion),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                progress.completedToday
                                    ? 'Target hari ini tercapai'
                                    : 'Sedikit demi sedikit',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${progress.todaySeconds ~/ 60} dari ${progress.targetSeconds ~/ 60} menit membaca',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completion,
                        minHeight: 7,
                        backgroundColor: SacredTheme.primary.withValues(
                          alpha: .10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(title: 'Jelajahi', trailing: null),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.menu_book_rounded,
                        label: 'Daftar surah',
                        caption: '114 surah',
                        onTap: widget.onOpenQuran,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'Tersimpan',
                        caption:
                            '${SharedPreferencesService.getBookmarks().length} bookmark',
                        onTap: () => openBookmarks(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _QuickAction(
                  icon: Icons.explore_rounded,
                  label: 'Arah kiblat',
                  caption: 'Lokasi presisi dan kompas perangkat',
                  onTap: widget.onOpenQibla,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.surah, required this.onTap});
  final SurahMeta surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        height: 216,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SacredTheme.primaryContainer, SacredTheme.primary],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -48,
              right: -42,
              child: Container(
                width: 182,
                height: 182,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SacredTheme.gold.withValues(alpha: .10),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 4,
              child: Text(
                'اقرأ',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 72,
                  height: 1,
                  color: Colors.white.withValues(alpha: .13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'LANJUTKAN BACA',
                      style: TextStyle(
                        color: SacredTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    surah.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${surah.revelation} · ${surah.ayahCount} ayat',
                    style: const TextStyle(color: Color(0xFFD7F0E4)),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: SacredTheme.gold,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Buka pembaca',
                        style: TextStyle(
                          color: Colors.white,
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
      ),
    ),
  );
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 54,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(value: value, strokeWidth: 6),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const Spacer(),
      if (trailing != null)
        Text(
          trailing!,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: SacredTheme.primary),
        ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SacredTheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: SacredTheme.primary),
            ),
            const SizedBox(height: 18),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
