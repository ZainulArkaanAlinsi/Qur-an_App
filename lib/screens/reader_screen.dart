import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.surah});
  final SurahMeta surah;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<List<String>> _verses;
  late ReadingSessionTracker _tracker;
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    SharedPreferencesService.setLastReadSurah(widget.surah.number);
    _verses = QuranTextRepository.instance.versesForSurah(widget.surah.number);
    _tracker = ReadingSessionTracker(onChanged: () {
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: _focusMode ? 56 : 68,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.surah.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (!_focusMode)
                Text(
                  '${widget.surah.ayahCount} ayat · ${widget.surah.revelation}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          actions: [
            if (!_focusMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SacredTheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _timerLabel(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SacredTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            IconButton(
              onPressed: () => setState(() => _focusMode = !_focusMode),
              icon: Icon(_focusMode
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded),
              tooltip: _focusMode ? 'Keluar dari mode fokus' : 'Mode fokus',
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: FutureBuilder<List<String>>(
          future: _verses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ReaderError(
                message: '${snapshot.error}',
                onRetry: () => setState(() {
                  _verses = QuranTextRepository.instance
                      .versesForSurah(widget.surah.number);
                }),
              );
            }
            final verses = snapshot.data!;
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(20, _focusMode ? 16 : 10, 20, 36),
              itemCount: verses.length + (_focusMode ? 0 : 1),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (!_focusMode && index == 0) return const _SourceNotice();
                final verseIndex = _focusMode ? index : index - 1;
                return _VerseCard(
                  verseNumber: verseIndex + 1,
                  arabic: verses[verseIndex],
                  surahNumber: widget.surah.number,
                );
              },
            );
          },
        ),
      );

  String _timerLabel() {
    final progress = ReadingProgressService.read();
    return '${progress.todaySeconds ~/ 60}/${progress.targetSeconds ~/ 60} m';
  }
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SacredTheme.gold.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.offline_pin_outlined,
                size: 20, color: SacredTheme.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Teks Arab tersedia offline. Terjemahan dan audio belum ditampilkan karena sumbernya masih diverifikasi.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52),
              const SizedBox(height: 14),
              const Text('Konten tidak dapat dibuka',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
}

class _VerseCard extends StatefulWidget {
  const _VerseCard({
    required this.verseNumber,
    required this.arabic,
    required this.surahNumber,
  });
  final int verseNumber;
  final String arabic;
  final int surahNumber;

  @override
  State<_VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<_VerseCard> {
  late bool bookmarked;

  @override
  void initState() {
    super.initState();
    bookmarked = SharedPreferencesService.isBookmarked(
      widget.surahNumber,
      widget.verseNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final arabicSize = SharedPreferencesService.getArabicFontSize();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark ? const Color(0xFF2A4036) : const Color(0xFFEEE5C8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SacredTheme.gold.withValues(alpha: .30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.verseNumber}',
                    style: const TextStyle(
                      color: SacredTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    if (bookmarked) {
                      await SharedPreferencesService.removeBookmark(
                        widget.surahNumber,
                        widget.verseNumber,
                      );
                    } else {
                      await SharedPreferencesService.saveBookmark(
                        widget.surahNumber,
                        widget.verseNumber,
                      );
                    }
                    if (mounted) setState(() => bookmarked = !bookmarked);
                  },
                  icon: Icon(bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded),
                  color: bookmarked ? SacredTheme.primary : null,
                  tooltip: bookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                widget.arabic,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: arabicSize,
                  height: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
