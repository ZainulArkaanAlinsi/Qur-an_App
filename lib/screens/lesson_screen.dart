import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/example_words.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Apakah materi draf boleh ditampilkan. Rilis: tidak; debug: ya, berlabel
/// (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
bool get showDraftLessons => kDebugMode;

/// Widget blok bacaan pelajaran, sama persis dengan halaman bacaan di
/// [LessonScreen]. Dipakai juga Sesi hari ini supaya materinya tampil sama.
List<Widget> lessonBlockWidgets(List<LessonBlock> blocks) =>
    _LessonScreenState._blocksOf(blocks);

/// Kartu satu soal latihan, sama dengan di [LessonScreen].
Widget lessonQuizCard({
  required QuizQuestion question,
  required int index,
  required int count,
  required int? picked,
  required ValueChanged<int> onPick,
}) => _PracticeCard(
  question: question,
  index: index,
  count: count,
  picked: picked,
  onPick: onPick,
);

/// Lencana DRAF (debug saja), sama dengan di [LessonScreen].
Widget lessonDraftBadge() => const _DraftBadge();

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
              // Lencana DRAF di pojok kanan atas; materi draf hanya bisa
              // dibuka di build debug (docs/design/v3/DESIGN.md §6).
              if (!widget.lesson.isPublished) const _DraftBadge(),
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
      ..._blocksOf(blocks),
    ];
  }

  /// Tiga contoh berkata-sorot atau lebih yang berurutan tampil sebagai
  /// daftar ringkas (docs/design/v3/DESIGN.md §6.3); blok lain apa adanya.
  static List<Widget> _blocksOf(List<LessonBlock> blocks) {
    final widgets = <Widget>[];
    var run = <LessonExample>[];
    void flush() {
      if (run.length >= 3) {
        widgets.add(_ExampleList(examples: run));
      } else {
        widgets.addAll([for (final example in run) _Example(example: example)]);
      }
      run = <LessonExample>[];
    }

    for (final block in blocks) {
      if (block is LessonExample && block.words != null) {
        run.add(block);
        continue;
      }
      flush();
      widgets.add(_BlockView(block: block));
    }
    flush();
    return widgets;
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

/// Penekanan sebaris di materi: `**tebal**` dan `*miring*`. Hanya dua itu;
/// tanda bintang lain tampil apa adanya.
final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*([^*\s][^*]*?)\*');

TextSpan _emphasized(String text, TextStyle base) {
  final bold = base.copyWith(
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 800)],
  );
  final italic = base.copyWith(fontStyle: FontStyle.italic);
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in _emphasis.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final strong = match.group(1);
    spans.add(
      strong != null
          ? TextSpan(text: strong, style: bold)
          : TextSpan(text: match.group(2), style: italic),
    );
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return TextSpan(style: base, children: spans);
}

/// Paragraf 15/22; `**teks**` ditebalkan dan `*teks*` dimiringkan.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text.rich(
        _emphasized(text, SacredText.lessonBody.copyWith(color: tokens.ink)),
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
              child: Text.rich(
                _emphasized(
                  text,
                  SacredText.infoBox.copyWith(color: tokens.primaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu huruf (docs/design/v3/DESIGN.md §6.4). 1–4 huruf sejajar satu
/// baris (Amiri 42, tinggi glyph 82); 5–15 huruf menjadi grid 5 kolom
/// (Amiri 32). Huruf yang punya ciri memakai 3 kolom supaya kata cirinya
/// tidak terpotong di tengah. Kartu tanpa ciri tidak menampilkan baris ketiga.
class _LetterCards extends StatelessWidget {
  const _LetterCards({required this.letters});

  final LessonLetters letters;

  @override
  Widget build(BuildContext context) {
    final items = letters.items;
    final compact = items.length > 4;
    final hasNotes = items.any((item) => item.note.isNotEmpty);
    final perRow = !compact ? items.length : (hasNotes ? 3 : 5);
    const gap = 8.0;
    final rows = <List<LessonLetter>>[
      for (var i = 0; i < items.length; i += perRow)
        items.sublist(i, (i + perRow).clamp(0, items.length)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: gap),
            // Kartu satu baris sama tinggi; baris terakhir grid tetap
            // selebar kolomnya, tidak melar.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < perRow; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    Expanded(
                      child: c < rows[r].length
                          ? _LetterCard(letter: rows[r][c], compact: compact)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.letter, required this.compact});

  final LessonLetter letter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final size = compact ? 32.0 : 42.0;
    final name = Text(
      letter.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: (compact ? SacredText.letterChip : SacredText.letterName).copyWith(
        color: tokens.ink,
      ),
    );
    return Semantics(
      label: [letter.name, if (letter.note.isNotEmpty) letter.note].join(', '),
      excludeSemantics: true,
      child: SacredCard(
        radius: compact ? 16 : 20,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 8 : 10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glyph diberi ruang setinggi 82 (Amiri 42) supaya ekor ya dan
            // mim tidak menimpa namanya; skalanya dibatasi pada teks besar.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(
                letter.letter,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: size,
                  height: compact ? 64 / 32 : 82 / 42,
                  color: tokens.primaryText,
                ),
              ),
            ),
            // Nama selalu utuh: di kolom sempit ia mengecil, bukan terpotong.
            FittedBox(fit: BoxFit.scaleDown, child: name),
            if (letter.note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                letter.note,
                textAlign: TextAlign.center,
                style: SacredText.letterNote.copyWith(color: tokens.sec),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lencana DRAF (debug saja) di pojok kanan atas layar pelajaran.
class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Semantics(
          label: 'Draf, belum ditinjau',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'DRAF',
              style: SacredText.draftBadge.copyWith(color: tokens.goldText),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayat contoh yang sudah dimuat: teks Tanzil apa adanya, awal tampilan
/// (sesudah basmalah bawaan), rentang kata yang disorot, dan warna tajwid.
class _ExampleVerse {
  const _ExampleVerse({
    required this.text,
    required this.start,
    required this.highlight,
    required this.tajweed,
  });

  final String text;
  final int start;
  final TanzilWord? highlight;
  final TajweedVerse? tajweed;

  String? get highlighted => highlight == null
      ? null
      : text.substring(highlight!.start, highlight!.end);

  /// Potongan [from, to) berwarna tajwid bila ada, polos bila tidak.
  List<InlineSpan> spans(SacredTokens tokens, {int? from, int? to}) {
    final begin = from ?? start;
    final end = to ?? text.length;
    final verse = tajweed;
    if (verse == null) return [TextSpan(text: text.substring(begin, end))];
    return tajweedSpans(
      verse,
      palette: TajweedPalette.draftPreview,
      brightness: tokens.isDark ? Brightness.dark : Brightness.light,
      base: tokens.ink,
      from: begin,
      to: end,
    );
  }

  static final _loaded = <String, _ExampleVerse>{};
  static final _loading = <String, Future<_ExampleVerse>>{};

  /// Dimuat sekali per contoh (dan per pilihan warna tajwid). Yang sudah
  /// dimuat dikembalikan seketika, jadi membuka lagi halaman atau lembar
  /// kartu ayat tidak berkedip "Memuat ayat…".
  static Future<_ExampleVerse> of(LessonExample example) {
    final colored = SharedPreferencesService.getReaderTajweed();
    final key = '${example.verseKey}|${example.words}|$colored';
    final loaded = _loaded[key];
    if (loaded != null) return SynchronousFuture(loaded);
    return _loading[key] ??= _load(example, colored: colored).then(
      (verse) {
        _loaded[key] = verse;
        _loading.remove(key);
        return verse;
      },
      // Kegagalan tidak disimpan: kunjungan berikutnya mencoba lagi.
      onError: (Object error, StackTrace stack) {
        _loading.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  static Future<_ExampleVerse> _load(
    LessonExample example, {
    required bool colored,
  }) async {
    final verses = await QuranTextRepository.instance.versesForSurah(
      example.surah,
    );
    final fatihah = await QuranTextRepository.instance.versesForSurah(1);
    final text = verses[example.ayah - 1];
    final words = exampleWords(
      surah: example.surah,
      ayah: example.ayah,
      verse: text,
      fatihahFirst: fatihah.first,
    );
    // Ayat 1 ditampilkan tanpa basmalah bawaan Tanzil (bukan bagian ayat).
    final start = example.ayah == 1
        ? basmalahPrefix(example.surah, text, fatihah.first)
        : 0;
    TajweedVerse? tajweed;
    if (colored) {
      // Warna tajwid hanya pelengkap: bila gagal, ayat tetap tampil polos.
      try {
        final surah = await TajweedRepository.instance.forSurah(example.surah);
        final verse = surah[example.ayah - 1];
        if (verse.text == text) tajweed = verse;
      } on Object {
        tajweed = null;
      }
    }
    return _ExampleVerse(
      text: text,
      start: start,
      highlight: highlightOf(words, example.words),
      tajweed: tajweed,
    );
  }
}

/// Gaya teks ayat contoh: Amiri Quran, baris 2.0.
TextStyle _verseStyle(SacredTokens tokens, double size) => TextStyle(
  fontFamily: SacredText.quran,
  fontSize: size,
  height: 2.0,
  color: tokens.ink,
);

/// Contoh ayat. Teks Arabnya diambil dari dataset, bukan dari materi; kata
/// yang dimaksud disorot (latar goldSoft, garis bawah goldText) dan juga
/// ditampilkan sendiri di atas ayat (DESIGN v3 §6.2).
class _Example extends StatefulWidget {
  const _Example({required this.example, this.inSheet = false});

  final LessonExample example;

  /// Di lembar bawah: tanpa jarak luar tambahan.
  final bool inSheet;

  @override
  State<_Example> createState() => _ExampleState();
}

class _ExampleState extends State<_Example> {
  late Future<_ExampleVerse> _verse = _ExampleVerse.of(widget.example);

  @override
  void didUpdateWidget(_Example old) {
    super.didUpdateWidget(old);
    if (old.example != widget.example) {
      _verse = _ExampleVerse.of(widget.example);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final example = widget.example;
    final surah = surahCatalog[example.surah - 1];
    return Padding(
      padding: widget.inSheet
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SacredCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'CONTOH',
                  style: SacredText.eyebrow.copyWith(color: tokens.sec),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${surah.displayName} · ${example.ayah}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.cardLabel.copyWith(color: tokens.sec),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FutureBuilder<_ExampleVerse>(
              future: _verse,
              builder: (context, snapshot) {
                final verse = snapshot.data;
                if (verse == null) {
                  return _Muted(
                    snapshot.hasError
                        ? 'Teks ayat gagal dimuat.'
                        : 'Memuat ayat…',
                  );
                }
                final highlight = verse.highlight;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (highlight != null)
                      // Kata yang disorot saja, supaya mata langsung
                      // menemukannya.
                      Text.rich(
                        TextSpan(
                          children: verse.spans(
                            tokens,
                            from: highlight.start,
                            to: highlight.end,
                          ),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        semanticsLabel:
                            'Kata yang dimaksud: ${verse.highlighted}',
                        style: _verseStyle(tokens, 26),
                      ),
                    _HighlightedVerse(
                      text: TextSpan(
                        style: _verseStyle(tokens, 30),
                        children: verse.spans(tokens),
                      ),
                      highlight: highlight == null
                          ? null
                          : TextRange(
                              start: highlight.start - verse.start,
                              end: highlight.end - verse.start,
                            ),
                      fill: tokens.goldSoft,
                      line: tokens.goldText,
                      textScaler: MediaQuery.textScalerOf(context),
                      semanticsLabel:
                          'Ayat ${example.ayah} ${surah.displayName}',
                    ),
                  ],
                );
              },
            ),
            if (example.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                example.note,
                style: SacredText.exampleNote.copyWith(color: tokens.sec),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Daftar ringkas untuk tiga contoh atau lebih: kata yang disorot, chip huruf
/// penentu, dan "Nama surah · ayat". Ketuk untuk membuka kartu ayat lengkap.
class _ExampleList extends StatelessWidget {
  const _ExampleList({required this.examples});

  final List<LessonExample> examples;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(22),
          boxShadow: tokens.cardShadows,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < examples.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: .5,
                    thickness: .5,
                    indent: 64,
                    color: tokens.sep,
                  ),
                _ExampleRow(example: examples[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatefulWidget {
  const _ExampleRow({required this.example});

  final LessonExample example;

  @override
  State<_ExampleRow> createState() => _ExampleRowState();
}

class _ExampleRowState extends State<_ExampleRow> {
  late Future<_ExampleVerse> _verse = _ExampleVerse.of(widget.example);

  @override
  void didUpdateWidget(_ExampleRow old) {
    super.didUpdateWidget(old);
    if (old.example != widget.example) {
      _verse = _ExampleVerse.of(widget.example);
    }
  }

  void _open() {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: tokens.sep,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Example(example: widget.example, inSheet: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final example = widget.example;
    final surah = surahCatalog[example.surah - 1];
    final letter = example.keyLetter;
    final place = '${surah.displayName} · ayat ${example.ayah}';
    return FutureBuilder<_ExampleVerse>(
      future: _verse,
      builder: (context, snapshot) {
        final verse = snapshot.data;
        final word = verse?.highlighted;
        return Semantics(
          button: true,
          label: [?word, if (letter != null) 'huruf $letter', place].join(', '),
          excludeSemantics: true,
          child: InkWell(
            onTap: _open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    // Chip huruf penentu dari keterangan; bila tidak ada,
                    // nomor surah (V3-Materi-Mutlak).
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: letter != null
                          ? Text(
                              letter,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 20,
                                height: 1.6,
                                color: tokens.primaryText,
                              ),
                            )
                          : Text(
                              '${example.surah}',
                              style: SacredText.rowTitle.copyWith(
                                color: tokens.primaryText,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (verse == null)
                            _Muted(
                              snapshot.hasError
                                  ? 'Teks ayat gagal dimuat.'
                                  : 'Memuat ayat…',
                            )
                          else
                            // Teks Arab tidak dipotong: kata panjang turun
                            // baris, bukan diberi elipsis.
                            Text.rich(
                              TextSpan(
                                children: verse.highlight == null
                                    ? verse.spans(tokens)
                                    : verse.spans(
                                        tokens,
                                        from: verse.highlight!.start,
                                        to: verse.highlight!.end,
                                      ),
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.left,
                              style: _verseStyle(tokens, 22),
                            ),
                          Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.rowSubtitle.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LineIcon(
                      SacredIcons.chevronRight,
                      color: tokens.tertiary,
                      size: 17,
                      strokeWidth: 2.2,
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

/// Ayat Arab dengan kata yang disorot: latar membulat (radius 6) dan garis
/// bawah 2 dp di belakang kata, tanpa memecah bentuk huruf Arab. Teksnya satu
/// paragraf utuh seperti Text biasa; sorotan dilukis di bawahnya.
class _HighlightedVerse extends LeafRenderObjectWidget {
  const _HighlightedVerse({
    required this.text,
    required this.highlight,
    required this.fill,
    required this.line,
    required this.textScaler,
    required this.semanticsLabel,
  });

  final TextSpan text;

  /// Rentang pada teks [text], atau null bila tidak ada sorotan.
  final TextRange? highlight;
  final Color fill;
  final Color line;
  final TextScaler textScaler;
  final String semanticsLabel;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHighlightedVerse(
        text: text,
        highlight: highlight,
        fill: fill,
        line: line,
        textScaler: textScaler,
        semanticsLabel: semanticsLabel,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHighlightedVerse renderObject,
  ) {
    renderObject
      ..text = text
      ..highlight = highlight
      ..fill = fill
      ..line = line
      ..textScaler = textScaler
      ..semanticsLabel = semanticsLabel;
  }
}

class _RenderHighlightedVerse extends RenderBox {
  _RenderHighlightedVerse({
    required TextSpan text,
    required TextRange? highlight,
    required Color fill,
    required Color line,
    required TextScaler textScaler,
    required String semanticsLabel,
  }) : _highlight = highlight,
       _fill = fill,
       _line = line,
       _semanticsLabel = semanticsLabel,
       _painter = TextPainter(
         text: text,
         textDirection: TextDirection.rtl,
         textAlign: TextAlign.right,
         textScaler: textScaler,
       );

  final TextPainter _painter;

  set text(TextSpan value) {
    switch (_painter.text!.compareTo(value)) {
      case RenderComparison.identical:
        return;
      case RenderComparison.paint:
        _painter.text = value;
        markNeedsPaint();
      case RenderComparison.layout:
      case RenderComparison.metadata:
        _painter.text = value;
        markNeedsLayout();
    }
  }

  TextRange? _highlight;
  set highlight(TextRange? value) {
    if (_highlight == value) return;
    _highlight = value;
    markNeedsPaint();
  }

  Color _fill;
  set fill(Color value) {
    if (_fill == value) return;
    _fill = value;
    markNeedsPaint();
  }

  Color _line;
  set line(Color value) {
    if (_line == value) return;
    _line = value;
    markNeedsPaint();
  }

  set textScaler(TextScaler value) {
    if (_painter.textScaler == value) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  String _semanticsLabel;
  set semanticsLabel(String value) {
    if (_semanticsLabel == value) return;
    _semanticsLabel = value;
    markNeedsSemanticsUpdate();
  }

  /// Menata teks selebar [maxWidth] penuh, supaya ayat pendek satu baris
  /// tetap rata kanan (seperti RenderParagraph dengan batas ketat).
  void _layoutText(double maxWidth) => maxWidth.isFinite
      ? _painter.layout(minWidth: maxWidth, maxWidth: maxWidth)
      : _painter.layout();

  @override
  double computeMinIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _painter.layout();
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  Size _sizeFor(BoxConstraints constraints) {
    _layoutText(constraints.maxWidth);
    return constraints.constrain(Size(_painter.width, _painter.height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints);

  @override
  void performLayout() => size = _sizeFor(constraints);

  /// Kotak sorotan per baris: gabungan kotak glyph pada rentang yang sama
  /// barisnya, sedikit dilebarkan.
  List<Rect> _highlightRects(Offset offset) {
    final range = _highlight;
    if (range == null || !range.isValid || range.isCollapsed) return const [];
    final boxes = _painter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      boxHeightStyle: ui.BoxHeightStyle.tight,
    );
    final lines = <Rect>[];
    for (final box in boxes) {
      final rect = box.toRect().shift(offset);
      final index = lines.indexWhere(
        (line) => (line.center.dy - rect.center.dy).abs() < rect.height / 2,
      );
      if (index < 0) {
        lines.add(rect);
      } else {
        lines[index] = lines[index].expandToInclude(rect);
      }
    }
    // Kotak glyph Amiri Quran bisa melewati tinggi baris; jangan sampai
    // sorotan menutupi widget di atas/bawahnya.
    final bounds = offset & size;
    return [for (final rect in lines) rect.inflate(3).intersect(bounds)];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Intrinsik bisa menata ulang painter dengan lebar lain; kembalikan ke
    // lebar tata letak sebenarnya sebelum melukis (hanya bila berbeda).
    if (_painter.width != size.width) _layoutText(size.width);
    final canvas = context.canvas;
    final fill = Paint()..color = _fill;
    final underline = Paint()
      ..color = _line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final rect in _highlightRects(offset)) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          fill,
        )
        ..drawLine(
          Offset(rect.left + 4, rect.bottom - 2),
          Offset(rect.right - 4, rect.bottom - 2),
          underline,
        );
    }
    _painter.paint(canvas, offset);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _semanticsLabel
      ..textDirection = TextDirection.rtl;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
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
