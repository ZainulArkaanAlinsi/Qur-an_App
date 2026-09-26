import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/learn/domain/quiz_session.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/presentation/session_screen.dart';
import 'package:quran_app_2025/features/session/presentation/session_verse_view.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/session_fakes.dart';

/// Alur layar Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §1,
/// §4, §6): lengkap, lewati, keluar-lanjut, izin mikrofon ditolak, offline,
/// dan hari berganti.
void main() {
  late VerseTexts texts;
  late Curriculum curriculum;
  late Directory documents;
  late FakeSessionAudio audio;
  late FakeSessionRecorder recorder;

  const today = '2026-09-26';
  final now = DateTime(2026, 9, 26, 9);

  setUpAll(() {
    texts = loadTanzilTexts();
    curriculum = loadCurriculum();
  });

  setUp(() {
    documents = Directory.systemTemp.createTempSync('sesi_layar_');
    audio = FakeSessionAudio();
    recorder = FakeSessionRecorder();
  });

  tearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  Future<SessionStore> seed(
    WidgetTester tester, [
    Map<String, Object> values = const {},
  ]) async {
    late SessionStore store;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues(values);
      await SharedPreferencesService.init();
      store = SessionStore(
        SharedPreferencesService.instance!,
        documents: () async => documents,
      );
    });
    return store;
  }

  Future<void> open(
    WidgetTester tester,
    SessionStore store, {
    int startLevel = 1,
    bool drafts = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: SessionScreen(
          audio: audio,
          recorder: recorder,
          store: store,
          now: () => now,
          includeDrafts: drafts,
          curriculum: Future.value(curriculum),
          loadTexts: (_) async => texts,
          loadTajweed: (_, _) async => null,
          startLevel: startLevel,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Judul langkah; daftar digulir ke atas dulu bila judulnya sudah lewat.
  Future<String> heading(WidgetTester tester) async {
    final title = find.byKey(const ValueKey('sesi-judul'));
    if (title.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await tester.pumpAndSettle();
    }
    return tester.widget<Text>(title).data!;
  }

  /// Membangun baris daftar yang belum tampil dengan menggulir ke sana.
  Future<Finder> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    return finder;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = (await reveal(tester, find.text(text))).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, Pattern label) async {
    final finder = (await reveal(tester, find.bySemanticsLabel(label))).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Menjawab soal yang sedang tampil dengan pilihan pertama yang terlihat.
  Future<void> answerQuiz(WidgetTester tester) async {
    final options = {
      for (final lesson in curriculum.lessons)
        for (final quiz in lesson.quizzes) ...quiz.options,
    };
    // Hanya di isi layar; angka penunjuk langkah ("2") bukan pilihan.
    final finder = find.descendant(
      of: find.byType(ListView),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && options.contains(widget.data),
      ),
    );
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  testWidgets('alur lengkap: materi maju, sesi selesai, nilai diri', (
    tester,
  ) async {
    final store = await seed(tester);
    await open(tester, store);

    // Pengguna baru: belum ada soal ulang, jadi tidak ada tombol Lewati.
    expect(await heading(tester), 'Pemanasan');
    expect(find.text('Lewati'), findsNothing);
    await tapText(tester, 'Lanjut');

    // Materi baru: bagian pertama huruf hijaiyah, lalu satu soal.
    expect(find.textContaining('Huruf hijaiyah ada 28'), findsOneWidget);
    await tapText(tester, 'Lanjut');
    expect(find.text('Cek pemahaman'), findsOneWidget);
    await answerQuiz(tester);
    await tapText(tester, 'Lanjut');
    expect(SharedPreferencesService.getLessonStep('huruf-hijaiyah'), 1);

    // Temukan di ayat: huruf pertama rotasi (alif).
    expect(
      find.bySemanticsLabel('Ketuk kata yang memuat huruf ا (alif).'),
      findsOneWidget,
    );
    final view = tester.widget<SessionVerseView>(find.byType(SessionVerseView));
    final choice = store.day(today)!.verse!;
    final wrong = [
      for (var i = 1; i <= view.verse.words.length; i++)
        if (!choice.words.contains(i)) i,
    ];
    if (wrong.isNotEmpty) {
      view.onWordTap!(wrong.first);
      await tester.pumpAndSettle();
      expect(find.text('Belum tepat. Coba kata lain.'), findsOneWidget);
    }
    view.onWordTap!(choice.words.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Benar.'), findsOneWidget);
    await tapText(tester, 'Lanjut');

    // Dengar & tirukan.
    expect(
      await reveal(tester, find.text(sessionNoGradingNote)),
      findsOneWidget,
    );
    await tapLabel(tester, RegExp('^Dengarkan qari'));
    expect(audio.played, 1);
    await tapLabel(tester, 'Rekam bacaanku');
    expect(recorder.permissionAsked, 1);
    await tapLabel(tester, 'Berhenti merekam');
    expect(File(recorder.path!).existsSync(), isTrue);
    expect(
      recorder.path,
      endsWith(
        '${SessionStore.recordingsFolder}${Platform.pathSeparator}'
        '${choice.surah}_${choice.ayah}_$today.m4a',
      ),
    );
    await tapLabel(tester, RegExp('^Putar rekamanku'));
    expect(recorder.plays, 1);
    await tapText(tester, 'Bergantian: Qari dan Suaraku');
    // Tiga putaran Qari → Suaraku, ditutup Qari.
    expect(audio.played, 1 + 4);
    expect(recorder.plays, 1 + 3);
    await tapText(tester, 'Lanjut');

    // Selesai: tidak bisa dilewati, penilaian diri.
    expect(find.text('Lewati'), findsNothing);
    await tapText(tester, 'Sudah mirip');
    await tapText(tester, 'Selesai');
    expect(find.text('Selesai hari ini'), findsOneWidget);
    expect(store.completedDates(), {today});
    expect(store.ratings().single.rating, SelfRating.mirip);
    expect(store.ratings().single.verseKey, choice.key);
    expect(store.verseHistory(), contains(choice.key));
    expect(store.day(today)!.tomorrow, isNotNull);
  });

  testWidgets('setiap langkah bisa dilewati kecuali Selesai', (tester) async {
    final store = await seed(tester, {
      'belajar_selesai': ['huruf-hijaiyah'],
    });
    await open(tester, store, startLevel: 2);

    for (final step in [
      SessionStep.warmup,
      SessionStep.newMaterial,
      SessionStep.findInVerse,
      SessionStep.listenRepeat,
    ]) {
      expect(store.day(today)!.step, step);
      await tapText(tester, 'Lewati');
    }
    expect(await heading(tester), 'Selesai');
    expect(find.text('Lewati'), findsNothing);
    expect(find.text('Dilewati'), findsNWidgets(4));
    // Materi yang dilewati tidak memajukan pelajaran.
    expect(SharedPreferencesService.getLessonStep('bentuk-sambung'), 0);
    await tapText(tester, 'Selesai');
    expect(store.completedDates(), {today});
    expect(store.day(today)!.skipped, hasLength(4));
    expect(store.ratings(), isEmpty);
  });

  testWidgets('keluar di tengah sesi lalu lanjut di langkah yang sama', (
    tester,
  ) async {
    final store = await seed(tester);
    await open(tester, store);
    await tapText(tester, 'Lanjut'); // pemanasan kosong
    await tapText(tester, 'Lewati'); // materi
    expect(await heading(tester), 'Temukan di ayat');
    final verse = store.day(today)!.verse;

    await tapLabel(tester, 'Tutup sesi');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(audio.returned, greaterThanOrEqualTo(1));

    await open(tester, store);
    expect(await heading(tester), 'Temukan di ayat');
    expect(store.day(today)!.verse, verse);
    expect(store.day(today)!.skipped, {SessionStep.newMaterial});
  });

  testWidgets('hari berganti: sesi kemarin tidak dibawa', (tester) async {
    final store = await seed(tester);
    await tester.runAsync(
      () => store.saveDay(
        const DailySession(
          date: '2026-09-25',
          step: SessionStep.listenRepeat,
          lessonId: 'huruf-hijaiyah',
        ),
      ),
    );
    await open(tester, store);
    expect(await heading(tester), 'Pemanasan');
    expect(store.day(today)!.step, SessionStep.warmup);
    expect(store.day('2026-09-25')!.completed, isFalse);
  });

  testWidgets('izin mikrofon ditolak: sesi tetap bisa selesai', (tester) async {
    recorder.allow = false;
    final store = await seed(tester);
    await open(tester, store);
    await tapText(tester, 'Lanjut');
    await tapText(tester, 'Lewati');
    await tapText(tester, 'Lewati');
    expect(await reveal(tester, find.text(sessionMicNote)), findsOneWidget);
    await tapLabel(tester, 'Rekam bacaanku');
    expect(find.textContaining('Izin mikrofon ditolak'), findsOneWidget);
    expect(recorder.path, isNull);
    await tapText(tester, 'Lanjut');
    await tapText(tester, 'Selesai');
    expect(store.completedDates(), {today});
  });

  testWidgets('offline tanpa audio terunduh: langkah 4 menjadi Rekam saja', (
    tester,
  ) async {
    audio.offline = true;
    final store = await seed(tester);
    await open(tester, store);
    await tapText(tester, 'Lanjut');
    await tapText(tester, 'Lewati');
    await tapText(tester, 'Lewati');
    expect(await heading(tester), 'Dengar & tirukan');
    expect(find.text('Perlu internet'), findsOneWidget);
    await tapLabel(tester, RegExp('^Dengarkan qari'));
    expect(await heading(tester), 'Rekam saja');
    expect(find.text('Bergantian: Qari dan Suaraku'), findsNothing);
    await tapLabel(tester, 'Rekam bacaanku');
    await tapLabel(tester, 'Berhenti merekam');
    expect(recorder.path, isNotNull);
    await tapText(tester, 'Lanjut');
    expect(find.text('Rekam saja'), findsOneWidget); // ringkasan
    await tapText(tester, 'Selesai');
    expect(store.completedDates(), {today});
  });

  testWidgets('pemanasan memakai soal ulang dan mencatat jawabannya', (
    tester,
  ) async {
    final store = await seed(tester, {
      'belajar_selesai': ['huruf-hijaiyah'],
    });
    await open(tester, store, startLevel: 2);
    expect(find.text('Lewati'), findsOneWidget);
    await answerQuiz(tester);
    final answered = SharedPreferencesService.getQuizHistory(
      'huruf-hijaiyah',
    ).values.where((record) => !record.neverSeen).toList();
    expect(answered, hasLength(1));
    expect(answered.single.lastDate, isNotNull);
    expect(find.text('Soal berikutnya'), findsOneWidget);
    expect(store.day(today)!.step, SessionStep.warmup);
  });

  testWidgets('materi draf tidak muncul di rilis', (tester) async {
    final store = await seed(tester);
    await open(tester, store, startLevel: 10);
    expect(find.text('DRAF'), findsNothing);
    final lessonId = store.day(today)!.lessonId!;
    expect(
      curriculum.lessons
          .firstWhere((lesson) => lesson.id == lessonId)
          .isPublished,
      isTrue,
    );
  });

  testWidgets('debug: materi draf tampil dengan lencana DRAF', (tester) async {
    final store = await seed(tester);
    await open(tester, store, startLevel: 10, drafts: true);
    expect(find.text('DRAF'), findsOneWidget);
  });

  test('QuizSession.ask menjaga jawaban benar', () {
    final quiz = curriculum.lessons
        .expand((lesson) => lesson.quizzes)
        .firstWhere((quiz) => quiz.options.length == 4);
    for (var round = 0; round < 10; round++) {
      final question = QuizSession.ask(quiz, round);
      expect(question.options[question.answer], quiz.options[quiz.answer]);
    }
  });
}
