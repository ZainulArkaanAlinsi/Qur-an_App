import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Apakah materi draf boleh ditampilkan. Rilis: tidak; debug: ya, berlabel
/// (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
bool get showDraftLessons => kDebugMode;

/// Satu pelajaran pada jalur belajar, ditampilkan blok demi blok.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late bool _done = SharedPreferencesService.getCompletedLessons().contains(
    widget.lesson.id,
  );

  Future<void> _toggleDone() async {
    final next = !_done;
    setState(() => _done = next);
    await SharedPreferencesService.setLessonCompleted(widget.lesson.id, next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final lesson = widget.lesson;
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(title: Text('Tahap ${lesson.level}')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Materi yang belum ditinjau tidak boleh tampak seolah sudah sahih.
          if (!lesson.isPublished) _DraftBanner(provenance: lesson.provenance),
          Text(
            lesson.title,
            style: SacredText.cardTitle.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.summary,
            style: SacredText.body.copyWith(color: tokens.sec),
          ),
          if (lesson.objectives.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Objectives(objectives: lesson.objectives),
          ],
          const SizedBox(height: 20),
          if (!lesson.hasContent)
            const _Notice(
              title: 'Materinya belum ditulis',
              body:
                  'Tahap ini baru berupa kerangka. Isinya menunggu penyusunan '
                  'dan pemeriksaan pengajar sebelum bisa dibaca.',
            )
          else
            for (final block in lesson.blocks) ...[
              _BlockView(block: block),
              const SizedBox(height: 14),
            ],
          if (lesson.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Sources(sources: lesson.sources),
          ],
          const SizedBox(height: 20),
          if (lesson.hasContent)
            FilledButton.icon(
              onPressed: _toggleDone,
              icon: Icon(
                _done ? Icons.check_circle : Icons.check_circle_outline,
              ),
              label: Text(_done ? 'Sudah selesai' : 'Tandai selesai'),
            ),
        ],
      ),
    );
  }
}

/// Label yang menyebut status materi apa adanya, beserta asal teksnya.
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.provenance});

  final String provenance;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRAF — BELUM DIREVIEW',
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          const SizedBox(height: 6),
          Text(
            provenance,
            style: SacredText.cardNote.copyWith(color: tokens.ink),
          ),
        ],
      ),
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.objectives});

  final List<String> objectives;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETELAH INI KAMU BISA',
            style: SacredText.eyebrow.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 8),
          for (final objective in objectives)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $objective',
                style: SacredText.body.copyWith(color: tokens.ink),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final LessonBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    LessonText(:final text) => _Paragraph(text: text),
    LessonTip(:final text) => _Tip(text: text),
    final LessonExample example => _Example(example: example),
    final LessonAudio audio => _Audio(audio: audio),
    final LessonQuiz quiz => _Quiz(quiz: quiz),
  };
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Text(text, style: SacredText.body.copyWith(color: tokens.ink));
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: SacredText.body.copyWith(color: tokens.primaryText),
      ),
    );
  }
}

/// Contoh ayat. Teks Arabnya diambil dari dataset, bukan dari materi.
class _Example extends StatelessWidget {
  const _Example({required this.example});

  final LessonExample example;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final surah = surahCatalog[example.surah - 1];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${surah.displayName} · ${example.verseKey}',
            style: SacredText.verseLabel.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<String>>(
            future: QuranTextRepository.instance.versesForSurah(example.surah),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Teks ayat gagal dimuat.',
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                );
              }
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
          if (example.note.isNotEmpty) ...[
            const SizedBox(height: 10),
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

/// Contoh bunyi. Selama rekamannya belum ada, keadaannya dikatakan apa adanya
/// dan tidak pernah diisi suara buatan.
class _Audio extends StatelessWidget {
  const _Audio({required this.audio});

  final LessonAudio audio;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: tokens.sec),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audio.label,
                  style: SacredText.listName.copyWith(color: tokens.ink),
                ),
                Text(
                  audio.isReady
                      ? 'Siap diputar.'
                      : 'Audio contoh sedang disiapkan — menunggu rekaman '
                            'pengajar yang berizin.',
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

/// Soal pemahaman. Bukan penilaian bacaan.
class _Quiz extends StatefulWidget {
  const _Quiz({required this.quiz});

  final LessonQuiz quiz;

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final quiz = widget.quiz;
    final answered = _picked != null;
    final correct = _picked == quiz.answer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATIHAN',
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          const SizedBox(height: 6),
          Text(
            quiz.question,
            style: SacredText.listName.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < quiz.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Option(
                label: quiz.options[i],
                selected: _picked == i,
                // Jawaban benar hanya ditandai setelah dijawab, supaya tidak
                // bocor dari warnanya sebelum dipilih.
                isAnswer: answered && i == quiz.answer,
                onTap: answered ? null : () => setState(() => _picked = i),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 4),
            Text(
              correct ? 'Betul.' : 'Belum tepat.',
              style: SacredText.listName.copyWith(
                color: correct ? tokens.primaryText : tokens.goldText,
              ),
            ),
            if (quiz.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quiz.explanation,
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _picked = null),
              child: const Text('Coba lagi'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.isAnswer,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isAnswer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final highlighted = isAnswer || selected;
    return Semantics(
      button: onTap != null,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isAnswer ? tokens.primarySoft : tokens.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? tokens.primaryText : tokens.sep,
              width: highlighted ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: SacredText.body.copyWith(
              color: isAnswer ? tokens.primaryText : tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<LessonSource> sources;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RUJUKAN', style: SacredText.eyebrow.copyWith(color: tokens.sec)),
        const SizedBox(height: 6),
        for (final source in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              [
                source.title,
                if (source.author.isNotEmpty) source.author,
                if (source.url.isNotEmpty) source.url,
              ].join(' · '),
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SacredText.listName.copyWith(color: tokens.ink)),
          const SizedBox(height: 6),
          Text(body, style: SacredText.body.copyWith(color: tokens.sec)),
        ],
      ),
    );
  }
}
