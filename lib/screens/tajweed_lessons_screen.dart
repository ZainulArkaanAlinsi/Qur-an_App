import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/data/tajweed_lesson_repository.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Materi tajwid. Seluruh penjelasannya berasal dari
/// `assets/learn/tajweed_lessons.json`, yang ditulis dan ditinjau manusia
/// (docs/TAJWEED_CONTENT.md). Aplikasi tidak pernah mengarang isinya.
class TajweedLessonsScreen extends StatefulWidget {
  const TajweedLessonsScreen({super.key});

  @override
  State<TajweedLessonsScreen> createState() => _TajweedLessonsScreenState();
}

class _TajweedLessonsScreenState extends State<TajweedLessonsScreen> {
  late Future<TajweedLessonBook> _book = TajweedLessonRepository.load();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(title: const Text('Akademi Tajwid')),
      body: SafeArea(
        child: FutureBuilder<TajweedLessonBook>(
          future: _book,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Notice(
                title: 'Materi tajwid tidak dapat dibaca',
                body:
                    'Berkas materinya ada tetapi bentuknya belum sesuai, jadi '
                    'tidak ditampilkan separuh-separuh.\n\n${snapshot.error}',
                onRetry: () =>
                    setState(() => _book = TajweedLessonRepository.load()),
              );
            }
            if (!snapshot.hasData) {
              return const _Notice(
                title: 'Memuat materi…',
                body: 'Sebentar.',
                onRetry: null,
              );
            }
            final book = snapshot.data!;
            if (!book.isReady) {
              return const _Notice(
                title: 'Materi tajwid belum dimuat',
                body:
                    'Penjelasan hukum tajwid ditulis dan ditinjau manusia, '
                    'bukan dibuat otomatis oleh aplikasi. Selama berkas '
                    'materinya masih kosong atau sumbernya belum dicantumkan, '
                    'halaman ini sengaja dibiarkan kosong.\n\n'
                    'Cara mengisinya ada di docs/TAJWEED_CONTENT.md.',
                onRetry: null,
              );
            }
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  '${book.lessons.length} hukum tajwid',
                  style: SacredText.cardLabel.copyWith(color: tokens.sec),
                ),
                const SizedBox(height: 12),
                for (final lesson in book.lessons) ...[
                  _LessonTile(lesson: lesson),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                _SourceNote(source: book.source),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: SacredText.headline.copyWith(color: tokens.ink)),
            const SizedBox(height: 8),
            Text(body, style: SacredText.body.copyWith(color: tokens.sec)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final TajweedLesson lesson;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _LessonScreen(lesson: lesson)),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.sep),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: SacredText.headline.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.summary,
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(CupertinoIcons.chevron_right, size: 18, color: tokens.sec),
          ],
        ),
      ),
    );
  }
}

class _LessonScreen extends StatelessWidget {
  const _LessonScreen({required this.lesson});

  final TajweedLesson lesson;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              lesson.summary,
              style: SacredText.headline.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 12),
            Text(
              lesson.detail,
              style: SacredText.body.copyWith(color: tokens.ink, height: 1.6),
            ),
            if (lesson.examples.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'CONTOH',
                style: SacredText.eyebrow.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 10),
              for (final example in lesson.examples) ...[
                _ExampleCard(example: example),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Teks Arab contoh diambil dari dataset, bukan dari berkas materi, sehingga
/// ayatnya tetap verbatim.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final TajweedExample example;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final surah = surahCatalog[example.surah - 1];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<String>>(
            future: QuranTextRepository.instance.versesForSurah(example.surah),
            builder: (context, snapshot) {
              final verses = snapshot.data;
              if (verses == null) {
                return Text(
                  'Memuat ayat…',
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                );
              }
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  verses[example.ayah - 1],
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: SharedPreferencesService.getArabicFontSize(),
                    height: SharedPreferencesService.getArabicLineHeight(),
                    color: tokens.ink,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'QS. ${surah.displayName} ${example.surah}:${example.ayah}',
            style: SacredText.cardLabel.copyWith(color: tokens.sec),
          ),
          if (example.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              example.note,
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source});

  final TajweedSource source;

  @override
  Widget build(BuildContext context) {
    return InsetGroupedList(
      header: 'Sumber materi',
      children: [
        ListTile(
          title: Text(source.title),
          subtitle: Text(
            [
              if (source.author.isNotEmpty) source.author,
              if (source.url.isNotEmpty) source.url,
              'Ditinjau oleh ${source.reviewedBy}'
                  '${source.reviewedOn.isEmpty ? '' : ' · ${source.reviewedOn}'}',
            ].join('\n'),
          ),
        ),
      ],
    );
  }
}
