import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Latihan satu pelajaran: bank soal dibagi per halaman, susunannya berubah
/// tiap ronde, dan soal yang pernah salah didahulukan.
class LessonQuizScreen extends StatefulWidget {
  const LessonQuizScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends State<LessonQuizScreen> {
  late Future<List<QuizQuestion>> _questions = _start();
  final _picked = <String, int>{};
  int _page = 0;

  Future<List<QuizQuestion>> _start() async {
    final round = await SharedPreferencesService.nextQuizRound();
    return QuizSession.build(
      bank: widget.lesson.quizzes,
      history: SharedPreferencesService.getQuizHistory(widget.lesson.id),
      round: round,
    );
  }

  Future<void> _answer(QuizQuestion question, int index) async {
    setState(() => _picked[question.id] = index);
    await SharedPreferencesService.recordQuizAnswer(
      widget.lesson.id,
      question.id,
      isCorrect: question.isCorrect(index),
    );
  }

  void _restart() {
    setState(() {
      _picked.clear();
      _page = 0;
      _questions = _start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(title: Text('Latihan · ${widget.lesson.title}')),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _questions,
        builder: (context, snapshot) {
          final questions = snapshot.data;
          if (questions == null) {
            return Center(
              child: Text(
                'Menyiapkan soal…',
                style: SacredText.body.copyWith(color: tokens.sec),
              ),
            );
          }
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Pelajaran ini belum punya soal latihan.',
                  textAlign: TextAlign.center,
                  style: SacredText.body.copyWith(color: tokens.sec),
                ),
              ),
            );
          }

          final pages = QuizSession.pageCount(questions.length);
          final onLastPage = _page >= pages - 1;
          final current = QuizSession.page(questions, _page);
          final answeredHere = current.every(
            (question) => _picked.containsKey(question.id),
          );
          final start = _page * QuizSession.perPage + 1;
          final end = start + current.length - 1;

          return Column(
            children: [
              _ProgressBar(
                label: 'Soal $start–$end dari ${questions.length}',
                value: (_page + 1) / pages,
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    for (final question in current) ...[
                      _QuestionCard(
                        question: question,
                        picked: _picked[question.id],
                        onPick: (index) => _answer(question, index),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (onLastPage && answeredHere) ...[
                      const SizedBox(height: 6),
                      _Summary(
                        questions: questions,
                        picked: _picked,
                        onRestart: _restart,
                      ),
                    ],
                  ],
                ),
              ),
              _Pager(
                page: _page,
                pages: pages,
                canGoForward: answeredHere && !onLastPage,
                onBack: _page == 0 ? null : () => setState(() => _page--),
                onForward: () => setState(() => _page++),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SacredText.cardNote.copyWith(color: tokens.sec)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: tokens.surf2,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.picked,
    required this.onPick,
  });

  final QuizQuestion question;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final answered = picked != null;
    final correct = answered && question.isCorrect(picked!);
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
            question.question,
            style: SacredText.listName.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Option(
                label: question.options[i],
                selected: picked == i,
                // Kunci hanya ditandai setelah dijawab, supaya tidak bocor
                // dari warnanya.
                isAnswer: answered && i == question.answer,
                onTap: answered ? null : () => onPick(i),
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
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                question.explanation,
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.questions,
    required this.picked,
    required this.onRestart,
  });

  final List<QuizQuestion> questions;
  final Map<String, int> picked;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final answered = questions
        .where((question) => picked.containsKey(question.id))
        .toList();
    final correct = answered
        .where((question) => question.isCorrect(picked[question.id]!))
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hasil latihan',
            style: SacredText.listName.copyWith(color: tokens.primaryText),
          ),
          const SizedBox(height: 4),
          Text(
            'Benar $correct dari ${answered.length} soal.',
            style: SacredText.body.copyWith(color: tokens.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Latihan berikutnya akan mendahulukan soal yang tadi salah, dan '
            'urutan pilihannya diacak lagi.',
            style: SacredText.cardNote.copyWith(color: tokens.primaryText),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Latihan lagi'),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pages,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final int page;
  final int pages;
  final bool canGoForward;
  final VoidCallback? onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Sebelumnya')),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Halaman ${page + 1} dari $pages',
                textAlign: TextAlign.center,
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              // Halaman berikutnya baru terbuka setelah semua soal di halaman
              // ini dijawab, supaya tidak ada yang terlewat diam-diam.
              onPressed: canGoForward ? onForward : null,
              child: const Text('Berikutnya'),
            ),
          ],
        ),
      ),
    );
  }
}
