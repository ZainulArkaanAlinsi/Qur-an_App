import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Apakah materi draf boleh ditampilkan. Rilis: tidak; debug: ya, berlabel
/// (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
bool get showDraftLessons => kDebugMode;

/// Pelajaran v2 (docs/design/v2/screens/09-pelajaran.md, V2-Pelajaran.png):
/// paham → dengar → coba, satu bagian per halaman.
///
/// - Tutup (✕) langsung keluar; bagian terjauh sudah tersimpan, jadi
///   "Lanjutkan" di Belajar kembali ke sana.
/// - Tombol kembali sistem mundur satu bagian dulu.
/// - Latihan: satu soal per kartu, jawaban terkunci setelah dipilih, lalu
///   penjelasan. Soal yang salah didahulukan di ronde berikutnya.
/// - Selesai latihan = tahap ditandai selesai.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, this.quizRound});

  final Lesson lesson;

  /// Hanya untuk tes: nomor ronde latihan yang tetap.
  @visibleForTesting
  final int? quizRound;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final List<List<LessonBlock>> _pages = widget.lesson.pages;
  late final bool _hasPractice = widget.lesson.quizzes.isNotEmpty;
  late final int _total = widget.lesson.stepCount;

  /// Bagian yang sedang tampil (0-based). Latihan = `_pages.length`.
  late int _step = _startStep();

  List<QuizQuestion>? _questions;
  int _question = 0;
  final _picked = <String, int>{};
  bool _finished = false;

  /// Soal per ronde latihan di dalam pelajaran.
  static const _perRound = QuizSession.perPage;

  int _startStep() {
    final lesson = widget.lesson;
    if (_total == 0) return 0;
    // Tahap yang sudah selesai dibuka dari awal untuk mengulang.
    if (SharedPreferencesService.getCompletedLessons().contains(lesson.id)) {
      return 0;
    }
    final reached = SharedPreferencesService.getLessonStep(lesson.id);
    return reached.clamp(0, _total - 1);
  }

  bool get _onPractice => _hasPractice && _step == _pages.length;

  @override
  void initState() {
    super.initState();
    if (_onPractice) _prepareQuiz();
  }

  Future<void> _prepareQuiz() async {
    final round =
        widget.quizRound ?? await SharedPreferencesService.nextQuizRound();
    final questions = QuizSession.build(
      bank: widget.lesson.quizzes,
      history: SharedPreferencesService.getQuizHistory(widget.lesson.id),
      round: round,
      limit: _perRound,
    );
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _question = 0;
      _picked.clear();
    });
  }

  Future<void> _answer(QuizQuestion question, int index) async {
    if (_picked.containsKey(question.id)) return;
    setState(() => _picked[question.id] = index);
    await SharedPreferencesService.recordQuizAnswer(
      widget.lesson.id,
      question.id,
      isCorrect: question.isCorrect(index),
    );
  }

  Future<void> _next() async {
    final lesson = widget.lesson;
    if (_onPractice) {
      final questions = _questions!;
      if (_question < questions.length - 1) {
        setState(() => _question++);
        return;
      }
      await _complete();
      return;
    }
    await SharedPreferencesService.setLessonStep(lesson.id, _step + 1);
    if (_step + 1 < _total) {
      setState(() => _step++);
      if (_onPractice) await _prepareQuiz();
    } else {
      await _complete();
    }
  }

  Future<void> _complete() async {
    await SharedPreferencesService.setLessonStep(widget.lesson.id, _total);
    await SharedPreferencesService.setLessonCompleted(widget.lesson.id, true);
    if (mounted) setState(() => _finished = true);
  }

  void _back() {
    if (_finished || _step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  /// Di latihan, Lanjut baru aktif setelah soal dijawab.
  bool get _canContinue {
    if (!_onPractice) return true;
    final questions = _questions;
    if (questions == null) return false;
    if (questions.isEmpty) return true;
    return _picked.containsKey(questions[_question].id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final empty = _total == 0;
    final lastQuestion =
        _onPractice &&
        _questions != null &&
        _question == _questions!.length - 1;
    return PopScope(
      // Kembali mundur satu bagian dulu; baru keluar dari bagian pertama.
      canPop: _finished || _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                step: _finished ? _total : _step + 1,
                total: _total,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('step-$_step-$_question-$_finished'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: _finished
                      ? _finishedPage(context)
                      : empty
                      ? _emptyPage(context)
                      : _onPractice
                      ? _practicePage(context)
                      : _readingPage(context, _pages[_step]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: SacredButton(
                  label: _finished || empty
                      ? 'Kembali ke jalur'
                      : lastQuestion
                      ? 'Selesai'
                      : 'Lanjut',
                  expand: true,
                  height: 54,
                  textStyle: SacredText.button.copyWith(fontSize: 16),
                  onTap: _finished || empty
                      ? () => Navigator.of(context).pop()
                      : _canContinue
                      ? _next
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, {required String title, String? sub}) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final lesson = widget.lesson;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ['Tahap ${lesson.level}', ?sub].join(' · ').toUpperCase(),
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          if (!lesson.isPublished) ...[
            const SizedBox(height: 4),
            Text(
              'DRAF · BELUM DITINJAU',
              style: SacredText.eyebrow.copyWith(color: tokens.danger),
            ),
          ],
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              title,
              style: SacredText.lessonTitle.copyWith(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _readingPage(BuildContext context, List<LessonBlock> blocks) {
    final lesson = widget.lesson;
    final heading = blocks.whereType<LessonText>().firstOrNull?.heading;
    return [
      _heading(
        context,
        title: heading ?? lesson.title,
        sub: heading == null ? null : lesson.title,
      ),
      for (final block in blocks) _BlockView(block: block),
    ];
  }

  List<Widget> _practicePage(BuildContext context) {
    final questions = _questions;
    return [
      _heading(context, title: 'Latihan', sub: widget.lesson.title),
      if (questions == null)
        const _Padded(child: _Muted('Menyiapkan soal…'))
      else if (questions.isEmpty)
        const _Padded(child: _Muted('Pelajaran ini belum punya soal latihan.'))
      else
        _PracticeCard(
          question: questions[_question],
          index: _question,
          count: questions.length,
          picked: _picked[questions[_question].id],
          onPick: (index) => _answer(questions[_question], index),
        ),
    ];
  }

  List<Widget> _emptyPage(BuildContext context) => [
    _heading(context, title: widget.lesson.title),
    const _Padded(
      child: _Muted(
        'Tahap ini baru berupa kerangka. Isinya menunggu penyusunan dan '
        'pemeriksaan pengajar sebelum bisa dibaca.',
      ),
    ),
  ];

  List<Widget> _finishedPage(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final lesson = widget.lesson;
    final questions = _questions ?? const <QuizQuestion>[];
    final correct = questions.where((question) {
      final pick = _picked[question.id];
      return pick != null && question.isCorrect(pick);
    }).length;
    final summary = questions.isEmpty
        ? lesson.title
        : correct == questions.length
        ? 'Benar $correct dari ${questions.length} soal.'
        : 'Benar $correct dari ${questions.length} soal. Soal yang belum '
              'tepat akan muncul lebih dulu di latihan berikutnya.';
    return [
      const SizedBox(height: 40),
      Center(
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tokens.gold, shape: BoxShape.circle),
          child: LineIcon(
            SacredIcons.checkCircle,
            color: tokens.onGold,
            size: 36,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          'Tahap ${lesson.level} selesai',
          textAlign: TextAlign.center,
          style: SacredText.lessonTitle.copyWith(color: tokens.ink),
        ),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          summary,
          textAlign: TextAlign.center,
          style: SacredText.lessonBody.copyWith(color: tokens.sec),
        ),
      ),
      const SizedBox(height: 28),
      _Padded(
        child: _SourceNote(
          sources: lesson.sources,
          provenance: lesson.provenance,
        ),
      ),
    ];
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: child);
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Text(text, style: SacredText.lessonBody.copyWith(color: tokens.sec));
  }
}

/// Tombol tutup 40, bar progres 8, penghitung "3/5".
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.total,
    required this.onClose,
  });

  final int step;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 16, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: SacredIcons.close,
            tooltip: 'Tutup pelajaran',
            iconSize: 18,
            strokeWidth: 2,
            onTap: onClose,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: 'Bagian $step dari $total',
              child: ProgressBar(
                value: total == 0 ? 0 : step / total,
                height: 8,
              ),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: Text(
                '$step/$total',
                style: SacredText.stepCounter.copyWith(color: tokens.sec),
              ),
            ),
          ],
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
    final LessonLetters letters => _LetterCards(letters: letters),
    final LessonExample example => _Example(example: example),
    final LessonAudio audio => _AudioSample(audio: audio),
    LessonQuiz() => const SizedBox.shrink(),
  };
}

/// Paragraf 15/22; `**teks**` ditebalkan.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final base = SacredText.lessonBody.copyWith(color: tokens.ink);
    final bold = base.copyWith(
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation('wght', 800)],
    );
    final parts = text.split('**');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            for (var i = 0; i < parts.length; i++)
              TextSpan(text: parts[i], style: i.isOdd ? bold : null),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LineIcon(SacredIcons.info, color: tokens.primaryText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: SacredText.infoBox.copyWith(color: tokens.primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu huruf besar (Amiri 52) dengan nama dan ciri.
class _LetterCards extends StatelessWidget {
  const _LetterCards({required this.letters});

  final LessonLetters letters;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final cards = [
      for (final item in letters.items)
        Semantics(
          label: '${item.name}, ${item.note}',
          excludeSemantics: true,
          child: SacredCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Huruf 52 sudah besar; skalanya dibatasi supaya tidak keluar
                // dari kartu pada teks besar.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    item.letter,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: SacredText.quran,
                      fontSize: 52,
                      height: 84 / 52,
                      color: tokens.primaryText,
                    ),
                  ),
                ),
                // Titik di bawah huruf (ب) tidak boleh menempel ke namanya.
                const SizedBox(height: 6),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: SacredText.letterName.copyWith(color: tokens.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  item.note,
                  textAlign: TextAlign.center,
                  style: SacredText.letterNote.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      // Maksimal tiga sejajar; lebih dari itu turun ke baris berikutnya.
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final perRow = cards.length < 3 ? cards.length : 3;
          final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SacredCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${surah.displayName} · ${example.verseKey}',
              style: SacredText.verseLabel.copyWith(color: tokens.sec),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: QuranTextRepository.instance.versesForSurah(
                example.surah,
              ),
              builder: (context, snapshot) {
                final verses = snapshot.data;
                if (verses == null) {
                  return _Muted(
                    snapshot.hasError
                        ? 'Teks ayat gagal dimuat.'
                        : 'Memuat ayat…',
                  );
                }
                return Text(
                  verses[example.ayah - 1],
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: 30,
                    height: 2.0,
                    color: tokens.ink,
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
      ),
    );
  }
}

/// Audio contoh. Rekaman manusia berizin diputar; bila belum ada, keadaannya
/// dikatakan apa adanya (tanpa TTS / suara buatan).
class _AudioSample extends StatefulWidget {
  const _AudioSample({required this.audio});

  final LessonAudio audio;

  @override
  State<_AudioSample> createState() => _AudioSampleState();
}

class _AudioSampleState extends State<_AudioSample> {
  AudioPlayer? _player;
  bool _playing = false;

  Future<void> _toggle() async {
    try {
      final player = _player ??= AudioPlayer();
      if (_playing) {
        await player.stop();
        if (mounted) setState(() => _playing = false);
        return;
      }
      await player.setAsset(widget.audio.asset!);
      if (mounted) setState(() => _playing = true);
      await player.play();
      if (mounted) setState(() => _playing = false);
    } on Object {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio contoh belum dapat diputar.')),
      );
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    if (widget.audio.isReady) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SacredButton(
          label: _playing ? 'Hentikan' : widget.audio.label,
          icon: _playing ? SacredIcons.pause : SacredIcons.headphones,
          tone: ButtonTone.soft,
          expand: true,
          height: 46,
          textStyle: SacredText.buttonSmall,
          onTap: _toggle,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CustomPaint(
        painter: _DashedBorder(color: tokens.sep, radius: 23),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineIcon(SacredIcons.headphones, color: tokens.sec, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Audio contoh sedang disiapkan',
                  textAlign: TextAlign.center,
                  style: SacredText.dashedNote.copyWith(color: tokens.sec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// Kartu LATIHAN: pertanyaan dan pilihan. Pilihan beraksara Arab tampil
/// besar sejajar (seperti mockup); pilihan teks tampil satu per baris.
class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.question,
    required this.index,
    required this.count,
    required this.picked,
    required this.onPick,
  });

  final QuizQuestion question;
  final int index;
  final int count;
  final int? picked;
  final ValueChanged<int> onPick;

  static final _arabic = RegExp(r'^[؀-ۿݐ-ݿ\s]+$');

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final arabic =
        question.options.length <= 4 &&
        question.options.every(_arabic.hasMatch);
    final pick = picked;
    final answered = pick != null;
    final correct = pick != null && question.isCorrect(pick);
    final options = [
      for (var i = 0; i < question.options.length; i++)
        _Option(
          label: question.options[i],
          arabic: arabic,
          state: !answered
              ? _OptionState.idle
              : i == question.answer
              ? _OptionState.correct
              : i == pick
              ? _OptionState.wrong
              : _OptionState.idle,
          onTap: answered ? null : () => onPick(i),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SacredCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LATIHAN · ${index + 1}/$count',
              style: SacredText.eyebrow.copyWith(color: tokens.sec),
            ),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: SacredText.question.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 12),
            if (arabic)
              Row(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: options[i]),
                  ],
                ],
              )
            else
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                options[i],
              ],
            if (answered) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  [
                    correct ? 'Benar' : 'Belum tepat',
                    if (question.explanation.isNotEmpty) question.explanation,
                  ].join(' — '),
                  style: SacredText.feedback.copyWith(
                    color: correct ? tokens.success : tokens.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.arabic,
    required this.state,
    required this.onTap,
  });

  final String label;
  final bool arabic;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (Color bg, Color? ring) = switch (state) {
      _OptionState.idle => (tokens.surf, null),
      _OptionState.correct => (tokens.successSoft, tokens.success),
      _OptionState.wrong => (tokens.dangerSoft, tokens.danger),
    };
    final radius = BorderRadius.circular(18);
    final text = arabic
        ? Text(
            label,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SacredText.quran,
              fontSize: 38,
              height: 1.6,
              color: tokens.ink,
            ),
          )
        : Text(label, style: SacredText.option.copyWith(color: tokens.ink));
    return Semantics(
      button: onTap != null,
      selected: state != _OptionState.idle,
      label: switch (state) {
        _OptionState.correct => '$label, jawaban benar',
        _OptionState.wrong => '$label, pilihanmu, belum tepat',
        _OptionState.idle => label,
      },
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: ring == null ? null : Border.all(color: ring, width: 2),
          boxShadow: ring == null ? tokens.cardShadows : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              constraints: BoxConstraints(minHeight: arabic ? 76 : 52),
              padding: arabic
                  ? const EdgeInsets.symmetric(vertical: 4)
                  : const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: arabic
                              ? Alignment.center
                              : AlignmentDirectional.centerStart,
                          child: text,
                        ),
                      ),
                      if (state == _OptionState.correct && !arabic)
                        LineIcon(
                          SacredIcons.checkCircle,
                          color: tokens.success,
                          size: 20,
                        ),
                    ],
                  ),
                  // Huruf besar: centang di pojok kanan atas (mockup).
                  if (state == _OptionState.correct && arabic)
                    Positioned(
                      right: 6,
                      top: 2,
                      child: LineIcon(
                        SacredIcons.checkCircle,
                        color: tokens.success,
                        size: 20,
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

/// Rujukan dan asal materi di halaman selesai.
class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.sources, required this.provenance});

  final List<LessonSource> sources;
  final String provenance;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final style = SacredText.cardNote.copyWith(color: tokens.sec);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sources.isNotEmpty) ...[
          Text(
            'RUJUKAN',
            style: SacredText.eyebrow.copyWith(color: tokens.sec),
          ),
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
                style: style,
              ),
            ),
          const SizedBox(height: 10),
        ],
        Text(
          'ASAL MATERI',
          style: SacredText.eyebrow.copyWith(color: tokens.sec),
        ),
        const SizedBox(height: 6),
        Text(provenance, style: style),
      ],
    );
  }
}
