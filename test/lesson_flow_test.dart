import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pelajaran uji: dua halaman bacaan (tip ikut halaman kedua) + satu soal.
const _lesson = Lesson(
  id: 'alur',
  level: 2,
  order: 1,
  title: 'Alur uji',
  summary: 'Ringkasan.',
  objectives: [],
  review: ContentReviewStatus.published,
  provenance: 'Data uji.',
  sources: [],
  blocks: [
    LessonText('Halaman satu.'),
    LessonText('Halaman dua.'),
    LessonTip('Tip ikut halaman dua.'),
    LessonQuiz(
      id: 'alur-1',
      question: 'Pilih benar',
      options: ['Benar', 'Salah'],
      answer: 0,
      explanation: 'Karena benar.',
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.light,
      home: const Scaffold(body: SizedBox()),
      routes: {
        '/lesson': (_) => const LessonScreen(lesson: _lesson, quizRound: 1),
      },
    ),
  );
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lesson');
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  test('tip, contoh, dan audio ikut halaman paragraf sebelumnya', () {
    expect(_lesson.pages, hasLength(2));
    expect(_lesson.pages[1].whereType<LessonTip>(), hasLength(1));
    expect(_lesson.stepCount, 3);
  });

  testWidgets(
    'maju per bagian, mundur dengan tombol kembali, progres tersimpan',
    (tester) async {
      await _pump(tester);
      expect(find.text('Halaman satu.'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman dua.'), findsOneWidget);
      expect(find.text('Tip ikut halaman dua.'), findsOneWidget);
      expect(SharedPreferencesService.getLessonStep('alur'), 1);

      // Tombol kembali sistem mundur satu bagian, bukan keluar.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Halaman satu.'), findsOneWidget);
    },
  );

  testWidgets('latihan: Lanjut terkunci sampai dijawab, lalu tahap selesai', (
    tester,
  ) async {
    await SharedPreferencesService.setLessonStep('alur', 2);
    await _pump(tester);
    expect(find.text('Pilih benar'), findsOneWidget);

    // Belum menjawab: Selesai tidak melakukan apa-apa.
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih benar'), findsOneWidget);

    await tester.tap(find.text('Salah'));
    await tester.pumpAndSettle();
    expect(find.text('Belum tepat — Karena benar.'), findsOneWidget);
    // Jawaban terkunci: memilih lagi tidak mengubahnya.
    await tester.tap(find.text('Benar'));
    await tester.pumpAndSettle();
    expect(find.text('Belum tepat — Karena benar.'), findsOneWidget);

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Tahap 2 selesai'), findsOneWidget);
    expect(find.textContaining('Benar 0 dari 1 soal.'), findsOneWidget);
    expect(SharedPreferencesService.getCompletedLessons(), contains('alur'));
    expect(SharedPreferencesService.getQuizHistory('alur'), contains('alur-1'));
  });

  testWidgets('✕ keluar langsung dan membuka lagi di bagian terakhir', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tutup pelajaran'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonScreen), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lesson');
    await tester.pumpAndSettle();
    expect(find.text('Halaman dua.'), findsOneWidget);
  });
}
