import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    SharedPreferencesService.setLastReadSurah(widget.surah.number);
    _verses = QuranTextRepository.instance.versesForSurah(widget.surah.number);
    _tracker = ReadingSessionTracker(
      onChanged: () {
        if (mounted) setState(() {});
      },
    )..start();
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.surah.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${widget.surah.ayahCount} ayat · ${widget.surah.revelation}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      actions: [
        Center(
          child: Text(
            _timerLabel(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 16),
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
            onRetry: () => setState(
              () => _verses = QuranTextRepository.instance.versesForSurah(
                widget.surah.number,
              ),
            ),
          );
        }
        final verses = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          itemCount: verses.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) return const _SourceNotice();
            return _VerseCard(
              verseNumber: index,
              arabic: verses[index - 1],
              surahNumber: widget.surah.number,
            );
          },
        );
      },
    ),
  );

  String _timerLabel() {
    final progress = ReadingProgressService.read();
    final minutes = progress.todaySeconds ~/ 60;
    return '$minutes/${progress.targetSeconds ~/ 60} m';
  }
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice();
  @override
  Widget build(BuildContext context) => Card(
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Teks Arab offline: Tanzil Quran Text (Uthmani v1.0.2). Terjemahan dan audio belum ditampilkan sampai sumber serta lisensinya tervalidasi.',
      ),
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
          const Icon(Icons.error_outline, size: 52),
          const SizedBox(height: 14),
          const Text(
            'Konten tidak dapat dibuka',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Text(
                    '${widget.verseNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  ),
                  tooltip: bookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                widget.arabic,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: arabicSize,
                  height: 1.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
