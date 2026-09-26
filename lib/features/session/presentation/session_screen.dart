import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/step_dots.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/domain/warmup_picker.dart';
import 'package:quran_app_2025/features/session/presentation/session_audio.dart';
import 'package:quran_app_2025/features/session/presentation/session_verse_view.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_legend_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_rule_sheet.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Pemuat teks Tanzil untuk sesi (Al-Fatihah, Juz 30, dan surah contoh).
typedef SessionTextLoader = Future<VerseTexts> Function(Curriculum curriculum);

/// Pemuat warna tajwid satu ayat, atau null bila tidak dipakai.
typedef SessionTajweedLoader =
    Future<TajweedVerse?> Function(int surah, int ayah);

/// Kalimat wajib langkah 4 (SESI_HARIAN.md §4).
const sessionNoGradingNote =
    'Aplikasi tidak menilai bacaanmu. Minta guru menyimak bila bisa.';

/// Penjelasan satu kalimat sebelum izin mikrofon diminta.
const sessionMicNote =
    'Mikrofon hanya dipakai saat kamu menekan Rekam, dan rekamannya tetap di '
    'HP ini.';

/// Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md): satu layar
/// penuh tanpa tab bar, lima langkah berurutan.
///
/// - Setiap langkah bisa dilewati kecuali Selesai.
/// - Tiap pergantian langkah disimpan di `sesi.hari.<tanggal>`, jadi keluar
///   di tengah sesi lalu membuka lagi pada hari yang sama melanjutkan dari
///   langkah itu.
/// - Aplikasi tidak menilai bacaan; langkah Selesai hanya penilaian diri.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    this.audio,
    this.recorder,
    this.store,
    this.now,
    this.includeDrafts,
    this.curriculum,
    this.loadTexts,
    this.loadTajweed,
    this.startLevel,
  });

  final SessionAudio? audio;
  final SessionRecorder? recorder;
  final SessionStore? store;

  /// Jam untuk menentukan tanggal sesi; bawaan `DateTime.now`.
  final DateTime Function()? now;

  /// Hanya untuk tes: paksa tampilan rilis (false) atau debug (true).
  final bool? includeDrafts;
  final Future<Curriculum>? curriculum;
  final SessionTextLoader? loadTexts;
  final SessionTajweedLoader? loadTajweed;

  /// Tahap titik mulai; bawaan pilihan onboarding.
  final int? startLevel;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final SessionAudio _audio = widget.audio ?? DeviceSessionAudio();
  late final SessionRecorder _recorder =
      widget.recorder ?? DeviceSessionRecorder();
  late final SessionStore? _store = widget.store ?? SessionStore.app;

  bool get _drafts => widget.includeDrafts ?? showDraftLessons;
  int get _startLevel => widget.startLevel ?? StartPoint.saved?.level ?? 0;
  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Object? _error;
  Curriculum? _curriculum;
  SessionPlan? _plan;
  DailySession? _session;
  VerseWords? _verse;
  TajweedVerse? _tajweed;

  // Pemanasan.
  List<(WarmupItem, QuizQuestion)> _warmup = const [];
  int _warmupIndex = 0;
  final _warmupPicked = <String, int>{};

  // Materi baru.
  bool _materialQuizPhase = false;
  List<QuizQuestion> _materialQuestions = const [];
  int _materialIndex = 0;
  final _materialPicked = <String, int>{};

  // Temukan di ayat.
  final _wrongTaps = <int>{};
  bool _found = false;
  bool _revealed = false;

  // Dengar & tirukan.
  bool _offline = false;
  bool? _qariLocal;
  bool _qariPlaying = false;
  bool _ownPlaying = false;
  bool _recording = false;
  bool _recorderFailed = false;
  bool _permissionDenied = false;
  String? _recordingPath;
  bool _pinned = false;
  final _levels = <double>[];
  StreamSubscription<double>? _levelSub;
  double _speed = 1;
  int _times = 1;
  int? _alternateRound;
  String? _alternatePart;
  bool _alternateStop = false;

  // Selesai.
  SelfRating? _rating;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_levelSub?.cancel());
    unawaited(_release());
    super.dispose();
  }

  /// Menghentikan semua suara sesi dan mengembalikan murottal.
  Future<void> _release() async {
    try {
      if (_recording) await _recorder.stop();
      await _recorder.stopPlayback();
      await _recorder.dispose();
    } on Object {
      // Perekam sudah tertutup.
    }
    try {
      await _audio.stopQari();
      await _audio.giveBack();
    } on Object {
      // Pemutar sudah tertutup.
    }
  }

  static Future<VerseTexts> _defaultTexts(Curriculum curriculum) async {
    final repository = QuranTextRepository.instance;
    final surahs = {
      ...shortVerseSurahs,
      for (final lesson in curriculum.lessons)
        for (final block in lesson.blocks)
          if (block is LessonExample) block.surah,
    };
    return {
      for (final surah in surahs) surah: await repository.versesForSurah(surah),
    };
  }

  static Future<TajweedVerse?> _defaultTajweed(int surah, int ayah) async {
    if (!SharedPreferencesService.getReaderTajweed()) return null;
    try {
      final verses = await TajweedRepository.instance.forSurah(surah);
      return ayah <= verses.length ? verses[ayah - 1] : null;
    } on Object {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final curriculum =
          await (widget.curriculum ?? CurriculumRepository.load());
      final texts = await (widget.loadTexts ?? _defaultTexts)(curriculum);
      final store = _store;
      final today = ReadingProgressService.localDate(_now());
      final plan = buildPlan(
        today: today,
        curriculum: curriculum,
        includeDrafts: _drafts,
        texts: texts,
        startLevel: _startLevel,
        completedLessons: SharedPreferencesService.getCompletedLessons(),
        lessonSteps: {
          for (final lesson in curriculum.lessons)
            lesson.id: SharedPreferencesService.getLessonStep(lesson.id),
        },
        quizHistory: {
          for (final lesson in curriculum.lessons)
            lesson.id: SharedPreferencesService.getQuizHistory(lesson.id),
        },
        verseHistory: store?.verseHistory() ?? const [],
        completedSessions: store?.completedCount() ?? 0,
        saved: store?.day(today),
      );
      final choice = plan.verse;
      final verse = choice == null
          ? null
          : verseWords(texts, choice.surah, choice.ayah);
      final tajweed = verse == null
          ? null
          : await (widget.loadTajweed ?? _defaultTajweed)(
              verse.surah,
              verse.ayah,
            );
      final round = dayNumber(today);
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
        _plan = plan;
        _session = plan.session;
        _verse = verse;
        _tajweed = tajweed;
        _warmup = [
          for (var i = 0; i < plan.warmup.length; i++)
            (plan.warmup[i], QuizSession.ask(plan.warmup[i].quiz, round + i)),
        ];
        _materialQuestions = [
          for (final quiz in plan.materialQuizzes) QuizSession.ask(quiz, round),
        ];
        _materialQuizPhase = plan.material.isEmpty;
      });
      await store?.saveDay(plan.session);
      await _enterStep(plan.session.step);
      if (store != null) unawaited(_cleanRecordings(store, today));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _cleanRecordings(SessionStore store, String today) async {
    try {
      await store.cleanRecordings(today: today);
    } on Object {
      // Folder dokumen tidak tersedia; dicoba lagi di sesi berikutnya.
    }
  }

  // ------------------------------------------------------------ alur

  Future<void> _enterStep(SessionStep step) async {
    final verse = _session?.verse;
    if (verse == null) return;
    if (step == SessionStep.findInVerse || step == SessionStep.listenRepeat) {
      await _store?.rememberVerse(verse.key);
    }
    if (step == SessionStep.listenRepeat) {
      final local = await _audio.hasOffline(verse.surah, verse.ayah);
      final store = _store;
      File? existing;
      if (store != null) {
        try {
          existing = await store.recordingFile(
            verse.surah,
            verse.ayah,
            _session!.date,
          );
        } on Object {
          existing = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _qariLocal = local;
        if (existing != null && existing.existsSync()) {
          _recordingPath = existing.path;
          _pinned = store!.pinned().contains(SessionStore.fileName(existing));
        }
      });
    }
  }

  /// Pindah ke langkah berikutnya; [skip] mencatatnya sebagai dilewati.
  Future<void> _advance({bool skip = false}) async {
    final session = _session;
    if (session == null || session.step == SessionStep.done) return;
    final from = session.step;
    if (!skip) await _finishStep(from);
    await _silence();
    final next = session.copyWith(
      step: from.next,
      skipped: skip ? {...session.skipped, from} : session.skipped,
    );
    if (!mounted) return;
    setState(() => _session = next);
    await _store?.saveDay(next);
    await _enterStep(next.step);
  }

  /// Materi baru yang dikerjakan sampai akhir memajukan pelajarannya, sama
  /// seperti di layar Pelajaran.
  Future<void> _finishStep(SessionStep step) async {
    final plan = _plan;
    final lesson = plan?.lesson;
    if (step != SessionStep.newMaterial || plan == null || lesson == null) {
      return;
    }
    final page = plan.session.materialPage ?? 0;
    final pages = lesson.pages.length;
    if (plan.material.isNotEmpty) {
      await SharedPreferencesService.setLessonStep(lesson.id, page + 1);
    }
    final practiceDone =
        plan.materialIsPractice &&
        _materialPicked.length == _materialQuestions.length;
    final readingDone =
        plan.material.isNotEmpty && page + 1 >= pages && lesson.quizzes.isEmpty;
    if (practiceDone || readingDone) {
      await SharedPreferencesService.setLessonStep(lesson.id, lesson.stepCount);
      await SharedPreferencesService.setLessonCompleted(lesson.id, true);
    }
  }

  Future<void> _silence() async {
    _alternateStop = true;
    if (_recording) await _stopRecording();
    try {
      await _audio.stopQari();
      await _recorder.stopPlayback();
    } on Object {
      // Tidak ada yang sedang diputar.
    }
    if (mounted) {
      setState(() {
        _qariPlaying = false;
        _ownPlaying = false;
        _alternateRound = null;
      });
    }
  }

  Future<void> _complete() async {
    final session = _session;
    final plan = _plan;
    final curriculum = _curriculum;
    if (session == null || plan == null || curriculum == null) return;
    final lesson = plan.lesson;
    final title = nextTitle(
      curriculum: curriculum,
      includeDrafts: _drafts,
      lesson: lesson,
      nextPage: lesson == null
          ? 0
          : SharedPreferencesService.getLessonStep(lesson.id),
      completedLessons: SharedPreferencesService.getCompletedLessons(),
      startLevel: _startLevel,
    );
    final done = session.copyWith(
      step: SessionStep.done,
      completed: true,
      rating: _rating,
      tomorrow: title,
    );
    final store = _store;
    await store?.saveDay(done);
    final verse = session.verse;
    final rating = _rating;
    if (store != null && verse != null) {
      await store.rememberVerse(verse.key);
      if (rating != null) {
        await store.addRating(
          RatingEntry(date: session.date, verseKey: verse.key, rating: rating),
        );
      }
    }
    if (mounted) setState(() => _session = done);
  }

  Future<void> _close() async {
    await _silence();
    if (mounted) await Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------ kuis

  Future<void> _answer(
    String lessonId,
    QuizQuestion question,
    int index,
    Map<String, int> picked,
  ) async {
    if (picked.containsKey(question.id)) return;
    setState(() => picked[question.id] = index);
    await SharedPreferencesService.recordQuizAnswer(
      lessonId,
      question.id,
      isCorrect: question.isCorrect(index),
    );
  }

  // ------------------------------------------------------ temukan di ayat

  void _tapWord(int position) {
    final verse = _session?.verse;
    if (verse == null || _found || _revealed) return;
    if (verse.words.contains(position)) {
      setState(() => _found = true);
    } else {
      setState(() => _wrongTaps.add(position));
    }
  }

  void _openRule(TajweedRule rule) {
    final tajweed = _tajweed;
    final verse = _verse;
    if (tajweed == null || verse == null) return;
    unawaited(
      showTajweedRuleSheet(
        context,
        verse: tajweed,
        rule: rule,
        palette: TajweedPalette.draftPreview,
        from: verse.words.isEmpty ? 0 : verse.words.first.start,
        onPlay: () => unawaited(_playQari()),
        onLegend: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TajweedLegendScreen(backLabel: 'Sesi'),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------- dengar & tirukan

  void _goOffline() {
    if (!mounted) return;
    setState(() {
      _offline = true;
      _qariPlaying = false;
      _alternateRound = null;
    });
  }

  Future<void> _playQari() async {
    final verse = _session?.verse;
    if (verse == null || _offline) return;
    if (_qariPlaying) {
      await _audio.stopQari();
      if (mounted) setState(() => _qariPlaying = false);
      return;
    }
    if (_recording) await _stopRecording();
    await _recorder.stopPlayback();
    setState(() {
      _qariPlaying = true;
      _ownPlaying = false;
    });
    try {
      await _audio.playQari(
        verse.surah,
        verse.ayah,
        times: _times,
        speed: _speed,
      );
    } on Object {
      _goOffline();
    }
    if (mounted) setState(() => _qariPlaying = false);
  }

  Future<void> _playOwn() async {
    final path = _recordingPath;
    if (path == null) return;
    if (_ownPlaying) {
      await _recorder.stopPlayback();
      if (mounted) setState(() => _ownPlaying = false);
      return;
    }
    await _audio.stopQari();
    setState(() {
      _ownPlaying = true;
      _qariPlaying = false;
    });
    try {
      await _recorder.play(path);
    } on Object {
      _say('Rekaman tidak dapat diputar.');
    }
    if (mounted) setState(() => _ownPlaying = false);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    final verse = _session?.verse;
    final store = _store;
    if (verse == null || store == null) return;
    await _audio.stopQari();
    await _recorder.stopPlayback();
    bool allowed;
    try {
      allowed = await _recorder.hasPermission();
    } on Object {
      allowed = false;
    }
    if (!mounted) return;
    if (!allowed) {
      setState(() => _permissionDenied = true);
      return;
    }
    try {
      await _audio.borrow();
      final file = await store.recordingFile(
        verse.surah,
        verse.ayah,
        _session!.date,
      );
      await _recorder.start(file.path);
    } on Object {
      if (mounted) setState(() => _recorderFailed = true);
      return;
    }
    _levels.clear();
    _levelSub = _recorder.amplitude().listen((level) {
      if (!mounted) return;
      setState(() {
        _levels.add(level);
        if (_levels.length > 240) _levels.removeAt(0);
      });
    });
    if (!mounted) return;
    setState(() {
      _recording = true;
      _permissionDenied = false;
      _recorderFailed = false;
      _qariPlaying = false;
      _ownPlaying = false;
    });
  }

  Future<void> _stopRecording() async {
    // Tombol langsung berubah; berkasnya menyusul setelah perekam berhenti.
    final levels = _levelSub;
    _levelSub = null;
    setState(() => _recording = false);
    unawaited(levels?.cancel());
    String? path;
    try {
      path = await _recorder.stop();
    } on Object {
      path = null;
    }
    final store = _store;
    if (!mounted || path == null) return;
    final name = SessionStore.fileName(File(path));
    setState(() {
      _recordingPath = path;
      _pinned = store?.pinned().contains(name) ?? false;
    });
  }

  Future<void> _alternate() async {
    final verse = _session?.verse;
    final path = _recordingPath;
    if (verse == null || path == null || _offline) return;
    if (_alternateRound != null) {
      _alternateStop = true;
      await _audio.stopQari();
      await _recorder.stopPlayback();
      if (mounted) setState(() => _alternateRound = null);
      return;
    }
    _alternateStop = false;
    setState(() {
      _qariPlaying = false;
      _ownPlaying = false;
    });
    // Qari → Suaraku, maksimal tiga putaran, ditutup qari sekali lagi supaya
    // yang terakhir terdengar adalah bacaan qari.
    for (var round = 1; round <= 3; round++) {
      for (final part in const ['Qari', 'Suaraku']) {
        if (_alternateStop || !mounted) break;
        setState(() {
          _alternateRound = round;
          _alternatePart = part;
        });
        try {
          if (part == 'Qari') {
            await _audio.playQari(verse.surah, verse.ayah, speed: _speed);
          } else {
            await _recorder.play(path);
          }
        } on Object {
          if (part == 'Qari') _goOffline();
          _alternateStop = true;
        }
      }
    }
    if (!_alternateStop && mounted) {
      setState(() => _alternatePart = 'Qari');
      try {
        await _audio.playQari(verse.surah, verse.ayah, speed: _speed);
      } on Object {
        _goOffline();
      }
    }
    if (mounted) setState(() => _alternateRound = null);
  }

  Future<void> _setPinned(bool value) async {
    final path = _recordingPath;
    final store = _store;
    if (path == null || store == null) return;
    await store.setPinned(SessionStore.fileName(File(path)), value);
    if (mounted) setState(() => _pinned = value);
  }

  Future<void> _deleteRecording() async {
    final path = _recordingPath;
    final store = _store;
    if (path == null || store == null) return;
    await _recorder.stopPlayback();
    await store.deleteRecording(File(path));
    if (!mounted) return;
    setState(() {
      _recordingPath = null;
      _pinned = false;
      _ownPlaying = false;
      _levels.clear();
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ tampilan

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final session = _session;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: _close, draft: _plan?.isDraft ?? false),
            if (session != null)
              StepDots(
                labels: [
                  for (final step in SessionStep.values) step.shortLabel,
                ],
                semanticLabels: [
                  for (final step in SessionStep.values) step.title,
                ],
                current: session.step.index,
              ),
            Expanded(
              child: _error != null
                  ? _Message(
                      text: 'Sesi hari ini gagal disiapkan.',
                      action: 'Coba lagi',
                      onAction: () {
                        setState(() => _error = null);
                        unawaited(_load());
                      },
                    )
                  : session == null
                  ? const _Message(text: 'Menyiapkan sesi…')
                  : ListView(
                      key: ValueKey(
                        'sesi-${session.step.name}-$_materialQuizPhase-'
                        '$_warmupIndex-$_materialIndex',
                      ),
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: switch (session.step) {
                        SessionStep.warmup => _warmupPage(context),
                        SessionStep.newMaterial => _materialPage(context),
                        SessionStep.findInVerse => _findPage(context),
                        SessionStep.listenRepeat => _listenPage(context),
                        SessionStep.done => _donePage(context),
                      },
                    ),
            ),
            if (session != null) _bottomBar(context, session),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title, {String? eyebrow}) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final step = _session!.step;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (eyebrow ?? 'Langkah ${step.index + 1} dari 5').toUpperCase(),
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              title,
              key: const ValueKey('sesi-judul'),
              style: SacredText.lessonTitle.copyWith(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _warmupPage(BuildContext context) {
    if (_warmup.isEmpty) {
      return [
        _heading(context, 'Pemanasan'),
        const _Note(
          'Belum ada soal untuk diulang. Soal dari pelajaran yang sudah kamu '
          'buka akan muncul di sini mulai besok.',
        ),
      ];
    }
    final (item, question) = _warmup[_warmupIndex];
    return [
      _heading(context, 'Pemanasan'),
      const _Note('Ulang sebentar yang sudah pernah kamu pelajari.'),
      lessonQuizCard(
        question: question,
        index: _warmupIndex,
        count: _warmup.length,
        picked: _warmupPicked[question.id],
        onPick: (index) =>
            unawaited(_answer(item.lessonId, question, index, _warmupPicked)),
      ),
    ];
  }

  List<Widget> _materialPage(BuildContext context) {
    final plan = _plan!;
    final lesson = plan.lesson;
    if (lesson == null) {
      return [
        _heading(context, 'Materi baru'),
        const _Note(
          'Semua materi yang sudah terbit selesai kamu pelajari. Ulangi tahap '
          'mana pun di Belajar, atau lanjutkan ke ayat hari ini.',
        ),
      ];
    }
    if (!_materialQuizPhase) {
      final heading = plan.material
          .whereType<LessonText>()
          .firstOrNull
          ?.heading;
      return [
        _heading(
          context,
          heading ?? lesson.title,
          eyebrow: 'Langkah 2 dari 5 · Tahap ${lesson.level}',
        ),
        ...lessonBlockWidgets(plan.material),
      ];
    }
    if (_materialQuestions.isEmpty) {
      return [
        _heading(context, lesson.title),
        const _Note('Pelajaran ini belum punya soal latihan.'),
      ];
    }
    final question = _materialQuestions[_materialIndex];
    return [
      _heading(
        context,
        plan.materialIsPractice ? 'Latihan' : 'Cek pemahaman',
        eyebrow: 'Langkah 2 dari 5 · ${lesson.title}',
      ),
      lessonQuizCard(
        question: question,
        index: _materialIndex,
        count: _materialQuestions.length,
        picked: _materialPicked[question.id],
        onPick: (index) =>
            unawaited(_answer(lesson.id, question, index, _materialPicked)),
      ),
    ];
  }

  String _verseLabel(VerseWords verse) =>
      '${surahCatalog[verse.surah - 1].displayName} · ${verse.ayah}';

  String _questionFor(VerseChoice choice) =>
      choice.focus?.question ??
      'Ketuk kata yang menjadi contoh ${_plan?.lesson?.title ?? 'hari ini'}.';

  /// Pertanyaan dengan huruf yang dicari ditulis besar memakai huruf mushaf,
  /// supaya alif atau titik kecil tidak hilang di font antarmuka.
  InlineSpan _questionSpan(VerseChoice choice, SacredTokens tokens) {
    final focus = choice.focus;
    if (focus is! LetterFocus) return TextSpan(text: _questionFor(choice));
    return TextSpan(
      children: [
        const TextSpan(text: 'Ketuk kata yang memuat huruf '),
        TextSpan(
          text: focus.letter.letter,
          style: TextStyle(
            fontFamily: SacredText.quran,
            fontSize: 28,
            height: 1.2,
            color: tokens.primaryText,
          ),
        ),
        TextSpan(text: ' (${focus.letter.name}).'),
      ],
    );
  }

  List<Widget> _findPage(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final choice = _session!.verse;
    final verse = _verse;
    if (choice == null || verse == null) {
      return [
        _heading(context, 'Temukan di ayat'),
        const _Note('Teks ayat belum bisa dimuat. Langkah ini bisa dilewati.'),
      ];
    }
    final answered = _found || _revealed;
    final feedback = _found
        ? 'Benar. Kata yang disorot memuat '
              '${choice.focus?.label ?? 'contoh itu'}.'
        : _revealed
        ? 'Ini kata yang dimaksud.'
        : _wrongTaps.isNotEmpty
        ? 'Belum tepat. Coba kata lain.'
        : null;
    return [
      _heading(context, 'Temukan di ayat'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Text.rich(
          _questionSpan(choice, tokens),
          semanticsLabel: _questionFor(choice),
          style: SacredText.question.copyWith(color: tokens.ink),
        ),
      ),
      _VerseCard(
        label: _verseLabel(verse),
        note: answered ? choice.note : null,
        child: SessionVerseView(
          verse: verse,
          semanticsLabel: 'Ayat ${verse.ayah} ${_verseLabel(verse)}',
          highlighted: answered ? choice.words.toSet() : const {},
          wrong: answered ? const {} : _wrongTaps,
          tajweed: answered ? _tajweed : null,
          onWordTap: answered ? null : _tapWord,
          onRuleTap: answered ? _openRule : null,
        ),
      ),
      if (feedback != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Semantics(
            liveRegion: true,
            child: Text(
              feedback,
              style: SacredText.feedback.copyWith(
                color: answered ? tokens.primaryText : tokens.danger,
              ),
            ),
          ),
        ),
      if (answered && _tajweed != null)
        const _Note('Ketuk huruf berwarna untuk melihat hukum tajwidnya.'),
    ];
  }

  List<Widget> _listenPage(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final choice = _session!.verse;
    final verse = _verse;
    if (choice == null || verse == null) {
      return [
        _heading(context, 'Dengar & tirukan'),
        const _Note('Teks ayat belum bisa dimuat. Langkah ini bisa dilewati.'),
      ];
    }
    final hasRecording = _recordingPath != null;
    final busy = _alternateRound != null;
    return [
      _heading(context, _offline ? 'Rekam saja' : 'Dengar & tirukan'),
      if (_offline)
        const _Note(
          'Audio qari untuk ayat ini belum terunduh dan belum bisa dimuat. '
          'Rekam bacaanmu dulu; qari bisa didengar nanti, dan sesi tetap '
          'dihitung selesai.',
        )
      else
        const _Note('Dengarkan qari, rekam bacaanmu, lalu bandingkan.'),
      _VerseCard(
        label: _verseLabel(verse),
        child: SessionVerseView(
          verse: verse,
          semanticsLabel: 'Ayat ${verse.ayah} ${_verseLabel(verse)}',
          highlighted: choice.words.toSet(),
          tajweed: _tajweed,
          onRuleTap: _openRule,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SacredCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BigButton(
                      icon: _qariPlaying
                          ? SacredIcons.pause
                          : SacredIcons.headphones,
                      label: 'Qari',
                      hint: _offline
                          ? 'Nanti'
                          : _qariPlaying
                          ? 'Berhenti'
                          : _qariLocal == false
                          ? 'Perlu internet'
                          : 'Dengarkan',
                      semanticsLabel: _qariPlaying
                          ? 'Hentikan qari'
                          : 'Dengarkan qari',
                      onTap: _offline || busy || _recording ? null : _playQari,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BigButton(
                      icon: _ownPlaying ? SacredIcons.pause : SacredIcons.play,
                      label: 'Suaraku',
                      hint: hasRecording
                          ? (_ownPlaying ? 'Berhenti' : 'Putar')
                          : 'Rekam dulu',
                      semanticsLabel: _ownPlaying
                          ? 'Hentikan rekamanku'
                          : 'Putar rekamanku',
                      onTap: hasRecording && !busy && !_recording
                          ? _playOwn
                          : null,
                    ),
                  ),
                ],
              ),
              if (!_offline) ...[
                const SizedBox(height: 14),
                _OptionRow(
                  label: 'Kecepatan qari',
                  child: SegmentedPill<int>(
                    segments: const {100: '1×', 75: '0,75×'},
                    value: (_speed * 100).round(),
                    onChanged: (value) => setState(() => _speed = value / 100),
                  ),
                ),
                const SizedBox(height: 8),
                _OptionRow(
                  label: 'Qari mengulang',
                  child: SegmentedPill<int>(
                    segments: const {1: '1×', 3: '3×'},
                    value: _times,
                    onChanged: (value) => setState(() => _times = value),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Levels(levels: _levels, active: _recording),
              const SizedBox(height: 10),
              Center(
                child: _RecordButton(
                  recording: _recording,
                  onTap: busy ? null : _toggleRecord,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _recording
                    ? 'Merekam… ketuk lagi untuk berhenti'
                    : hasRecording
                    ? 'Rekam ulang'
                    : 'Rekam',
                textAlign: TextAlign.center,
                style: SacredText.cardLabel.copyWith(color: tokens.ink),
              ),
              if (_permissionDenied || _recorderFailed) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _permissionDenied
                        ? 'Izin mikrofon ditolak. Sesi tetap bisa '
                              'diselesaikan; izinkan mikrofon di pengaturan HP '
                              'bila ingin merekam.'
                        : 'Perekam tidak tersedia di perangkat ini. Sesi '
                              'tetap bisa diselesaikan.',
                    textAlign: TextAlign.center,
                    style: SacredText.feedback.copyWith(color: tokens.danger),
                  ),
                ),
              ],
              if (!_offline) ...[
                const SizedBox(height: 14),
                SacredButton(
                  label: busy
                      ? 'Hentikan · putaran $_alternateRound dari 3 · '
                            '$_alternatePart'
                      : 'Bergantian: Qari dan Suaraku',
                  icon: SacredIcons.repeat,
                  tone: ButtonTone.soft,
                  expand: true,
                  onTap: hasRecording && !_recording ? _alternate : null,
                ),
              ],
              if (hasRecording && !_recording) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Simpan lebih dari 30 hari',
                        style: SacredText.rowSubtitle.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    IosToggle(
                      value: _pinned,
                      semanticsLabel: 'Simpan rekaman lebih dari 30 hari',
                      onChanged: busy ? null : _setPinned,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: busy ? null : _deleteRecording,
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.danger,
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      'Hapus rekaman',
                      style: SacredText.linkLabel.copyWith(
                        color: tokens.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const _Tip(sessionNoGradingNote),
      const _Note(sessionMicNote),
    ];
  }

  List<Widget> _donePage(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final session = _session!;
    final verse = _verse;
    final lesson = _plan?.lesson;
    String status(SessionStep step, String done) =>
        session.skipped.contains(step) ? 'Dilewati' : done;
    final correct = _warmup.where((entry) {
      final pick = _warmupPicked[entry.$2.id];
      return pick != null && entry.$2.isCorrect(pick);
    }).length;
    final rows = [
      ListRow(
        leading: const SoftIconCircle(icon: SacredIcons.repeat),
        title: 'Pemanasan',
        subtitle: status(
          SessionStep.warmup,
          _warmupPicked.isEmpty
              ? (_warmup.isEmpty ? 'Belum ada soal ulang' : 'Selesai')
              : 'Benar $correct dari ${_warmupPicked.length} soal',
        ),
      ),
      ListRow(
        leading: const SoftIconCircle(icon: SacredIcons.cap),
        title: 'Materi baru',
        subtitle: status(
          SessionStep.newMaterial,
          lesson == null ? 'Semua materi selesai' : lesson.title,
        ),
      ),
      ListRow(
        leading: const SoftIconCircle(icon: SacredIcons.book),
        title: 'Temukan di ayat',
        subtitle: status(
          SessionStep.findInVerse,
          verse == null ? 'Ayat belum dimuat' : _verseLabel(verse),
        ),
      ),
      ListRow(
        leading: const SoftIconCircle(icon: SacredIcons.mic),
        title: _offline ? 'Rekam saja' : 'Dengar & tirukan',
        subtitle: status(
          SessionStep.listenRepeat,
          _recordingPath != null ? 'Rekaman tersimpan di HP' : 'Selesai',
        ),
      ),
    ];

    if (session.completed) {
      final streak = ReadingProgressService.read(now: _now()).currentStreak;
      final line = [
        if (streak > 0) 'Istiqamah $streak hari',
        if (session.tomorrow case final next?) 'Besok: $next',
      ].join(' · ');
      return [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.gold,
              shape: BoxShape.circle,
            ),
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
            'Selesai hari ini',
            key: const ValueKey('sesi-judul'),
            textAlign: TextAlign.center,
            style: SacredText.lessonTitle.copyWith(color: tokens.ink),
          ),
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: SacredText.lessonBody.copyWith(color: tokens.sec),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GroupedList(label: 'Ringkasan', children: rows),
        ),
      ];
    }

    return [
      _heading(context, 'Selesai'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Text(
          'Bagaimana bacaanmu dibanding qari?',
          style: SacredText.question.copyWith(color: tokens.ink),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            for (final rating in SelfRating.values) ...[
              if (rating != SelfRating.values.first) const SizedBox(width: 10),
              Expanded(
                child: _RatingButton(
                  label: rating.label,
                  selected: _rating == rating,
                  onTap: () => setState(
                    () => _rating = _rating == rating ? null : rating,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const _Note(
        'Ini penilaianmu sendiri dan hanya tersimpan di HP. Bila bisa, '
        'perdengarkan bacaanmu kepada guru.',
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GroupedList(label: 'Ringkasan', children: rows),
      ),
    ];
  }

  Widget _bottomBar(BuildContext context, DailySession session) {
    final step = session.step;
    String label;
    VoidCallback? onTap;
    var canSkip = step.skippable;
    switch (step) {
      case SessionStep.warmup:
        final empty = _warmup.isEmpty;
        final answered =
            !empty && _warmupPicked.containsKey(_warmup[_warmupIndex].$2.id);
        final last = empty || _warmupIndex == _warmup.length - 1;
        label = last ? 'Lanjut' : 'Soal berikutnya';
        onTap = empty
            ? _advance
            : !answered
            ? null
            : last
            ? _advance
            : () => setState(() => _warmupIndex++);
        canSkip = !empty;
      case SessionStep.newMaterial:
        final plan = _plan!;
        if (plan.lesson == null) {
          label = 'Lanjut';
          onTap = _advance;
          canSkip = false;
        } else if (!_materialQuizPhase) {
          label = 'Lanjut';
          onTap = _materialQuestions.isEmpty
              ? _advance
              : () => setState(() => _materialQuizPhase = true);
        } else if (_materialQuestions.isEmpty) {
          label = 'Lanjut';
          onTap = _advance;
        } else {
          final question = _materialQuestions[_materialIndex];
          final last = _materialIndex == _materialQuestions.length - 1;
          label = last ? 'Lanjut' : 'Soal berikutnya';
          onTap = !_materialPicked.containsKey(question.id)
              ? null
              : last
              ? _advance
              : () => setState(() => _materialIndex++);
        }
      case SessionStep.findInVerse:
        final ready = _found || _revealed || _verse == null;
        label = ready ? 'Lanjut' : 'Tunjukkan jawaban';
        onTap = ready ? _advance : () => setState(() => _revealed = true);
      case SessionStep.listenRepeat:
        label = 'Lanjut';
        onTap = _advance;
      case SessionStep.done:
        canSkip = false;
        label = session.completed ? 'Tutup' : 'Selesai';
        onTap = session.completed
            ? () => Navigator.of(context).maybePop()
            : _complete;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          if (canSkip) ...[
            SacredButton(
              label: 'Lewati',
              tone: ButtonTone.fill,
              height: 54,
              onTap: () => _advance(skip: true),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SacredButton(
              label: label,
              expand: true,
              height: 54,
              textStyle: SacredText.button.copyWith(fontSize: 16),
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol tutup, judul "Sesi hari ini", dan lencana DRAF bila perlu.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.draft});

  final VoidCallback onClose;
  final bool draft;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 16, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: SacredIcons.close,
            tooltip: 'Tutup sesi',
            iconSize: 18,
            strokeWidth: 2,
            onTap: onClose,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sesi hari ini',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.navTitle.copyWith(color: tokens.ink),
            ),
          ),
          if (draft) lessonDraftBadge(),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: SacredText.lessonBody.copyWith(color: tokens.sec),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              SacredButton(label: action!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(
        text,
        style: SacredText.lessonBody.copyWith(color: tokens.sec),
      ),
    );
  }
}

/// Kotak hijau lembut, sama dengan blok tip di Pelajaran.
class _Tip extends StatelessWidget {
  const _Tip(this.text);

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

/// Kartu ayat: "Nama surah · ayat" lalu teks ayat.
class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.label, required this.child, this.note});

  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SacredCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'AYAT',
                  style: SacredText.eyebrow.copyWith(color: tokens.sec),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.cardLabel.copyWith(color: tokens.sec),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note!,
                style: SacredText.exampleNote.copyWith(color: tokens.sec),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tombol besar Qari / Suaraku: ikon, nama, dan keterangan keadaan.
class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.semanticsLabel,
    required this.onTap,
  });

  final List<String> icon;
  final String label;
  final String hint;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$semanticsLabel, $hint',
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Material(
          color: tokens.primarySoft,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LineIcon(icon, color: tokens.primaryText, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: SacredText.rowTitle.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: SacredText.rowSubtitle.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label di kiri, pilihan di kanan; pada teks besar pilihan turun ke bawah.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(label, style: SacredText.rowSubtitle.copyWith(color: tokens.ink)),
        child,
      ],
    );
  }
}

/// Bar amplitudo sederhana dari `onAmplitudeChanged`: 32 batang.
class _Levels extends StatelessWidget {
  const _Levels({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    const count = 32;
    final List<double> shown;
    if (levels.length <= count) {
      shown = [...List.filled(count - levels.length, 0.0), ...levels];
    } else if (active) {
      shown = levels.sublist(levels.length - count);
    } else {
      // Rekaman selesai: seluruhnya diringkas menjadi 32 batang.
      final step = levels.length / count;
      shown = [
        for (var i = 0; i < count; i++)
          levels
              .sublist((i * step).floor(), ((i + 1) * step).floor())
              .fold<double>(0, (a, b) => a > b ? a : b),
      ];
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            for (final level in shown)
              Expanded(
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4 + 32 * level,
                    decoration: BoxDecoration(
                      color: active ? tokens.danger : tokens.primaryText,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol rekam bulat 72 di tengah.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: recording ? 'Berhenti merekam' : 'Rekam bacaanku',
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: recording ? tokens.danger : tokens.cta,
              shape: BoxShape.circle,
            ),
            child: recording
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: tokens.surf,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  )
                : LineIcon(SacredIcons.mic, color: tokens.ctaInk, size: 30),
          ),
        ),
      ),
    );
  }
}

/// Pilihan penilaian diri "Sudah mirip" / "Masih beda".
class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? tokens.primarySoft : tokens.surf,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? tokens.primaryText : tokens.sep,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SacredText.option.copyWith(
                color: selected ? tokens.primaryText : tokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
