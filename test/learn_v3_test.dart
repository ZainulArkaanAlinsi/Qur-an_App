import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Belajar & Pelajaran v3 (docs/design/v3/DESIGN.md §5b, §6).
void main() {
  setUpAll(() async => CurriculumRepository.load());

  Future<void> seed([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    await SharedPreferencesService.init();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(body: child),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Lesson fixture({
    ContentReviewStatus review = ContentReviewStatus.draft,
    List<LessonBlock> blocks = const [],
  }) => Lesson(
    id: 'uji-v3',
    level: 10,
    order: 1,
    title: 'Uji',
    summary: 'Uji.',
    objectives: const [],
    blocks: blocks,
    sources: const [],
    review: review,
    provenance: 'Data uji.',
  );

  group('Pelajaran', () {
    testWidgets('**tebal** dan *miring* dirender, tanpa tanda bintang', (
      tester,
    ) async {
      await seed();
      await pump(
        tester,
        LessonScreen(
          lesson: fixture(
            blocks: const [
              LessonText('Bertemu **ya** (hafalan: *yanmu*).', heading: 'A'),
              LessonTip('Dengung **dua harakat**; hafalan *khuṣṣa*.'),
            ],
          ),
          quizRound: 1,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('*'), findsNothing);
      expect(find.textContaining('yanmu'), findsOneWidget);
      final spans = <TextSpan>[];
      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        text.text.visitChildren((span) {
          if (span is TextSpan) spans.add(span);
          return true;
        });
      }
      expect(
        spans.any(
          (span) =>
              span.text == 'yanmu' && span.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text == 'dua harakat' &&
              span.style?.fontWeight == FontWeight.w800,
        ),
        isTrue,
      );
    });

    testWidgets('lencana DRAF hanya untuk materi draf', (tester) async {
      await seed();
      await pump(
        tester,
        LessonScreen(
          lesson: fixture(blocks: const [LessonText('Isi.')]),
          quizRound: 1,
        ),
      );
      expect(find.text('DRAF'), findsOneWidget);

      await pump(
        tester,
        LessonScreen(
          lesson: fixture(
            review: ContentReviewStatus.published,
            blocks: const [LessonText('Isi.')],
          ),
          quizRound: 1,
        ),
      );
      expect(find.text('DRAF'), findsNothing);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('15 huruf menjadi grid 5 kolom tanpa overflow (×$scale)', (
        tester,
      ) async {
        await seed();
        const names = [
          'Ta', 'Tsa', 'Jim', 'Dal', 'Dzal', 'Zai', 'Sin', 'Syin', //
          'Shad', 'Dhad', 'Tha', 'Zha', 'Fa', 'Qaf', 'Kaf',
        ];
        await pump(
          tester,
          LessonScreen(
            lesson: fixture(
              blocks: [
                const LessonText('Huruf ikhfa.', heading: 'Ikhfa'),
                LessonLetters([
                  for (final name in names)
                    LessonLetter(letter: 'ت', name: name, note: ''),
                ]),
              ],
            ),
            quizRound: 1,
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        // Kartu pertama tiap baris sejajar di kiri: 3 baris × 5 kolom.
        final lefts = {
          for (final name in names)
            tester.getCenter(find.text(name)).dx.round(),
        };
        expect(lefts, hasLength(5));
        final tops = {
          for (final name in names)
            tester.getCenter(find.text(name)).dy.round(),
        };
        expect(tops, hasLength(3));
      });
    }
  });

  group('Belajar mengikuti titik mulai', () {
    testWidgets('tajwid di rilis: kartu "Materi sedang ditinjau" + Lanjutkan', (
      tester,
    ) async {
      await seed({'belajar.titikMulai': 'tajwid'});
      await pump(tester, const LearnScreen(includeDrafts: false));
      expect(tester.takeException(), isNull);
      expect(find.text('Nun sukun dan tanwin'), findsOneWidget);
      expect(find.text('Materi sedang ditinjau'), findsWidgets);
      expect(find.textContaining('lanjutkan Tahap 0'), findsOneWidget);

      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();
      final lesson = tester.widget<LessonScreen>(find.byType(LessonScreen));
      expect(lesson.lesson.isPublished, isTrue);
      expect(lesson.lesson.id, 'mulai');
    });

    testWidgets('tajwid di debug: tahap 10 menjadi tahap aktif', (
      tester,
    ) async {
      await seed({'belajar.titikMulai': 'tajwid'});
      await pump(tester, const LearnScreen(includeDrafts: true));
      expect(find.text('Nun sukun dan tanwin'), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget, reason: 'kartu tahap aktif');
      expect(find.text('Materi sedang ditinjau'), findsNothing);
    });

    testWidgets('nol: tahap 1 aktif walau tahap 0 belum dibuka', (
      tester,
    ) async {
      await seed({'belajar.titikMulai': 'nol'});
      await pump(tester, const LearnScreen(includeDrafts: false));
      final active = find.ancestor(
        of: find.text('Mulai'),
        matching: find.byType(Column),
      );
      expect(
        find.descendant(
          of: active.first,
          matching: find.text('Huruf hijaiyah'),
        ),
        findsOneWidget,
      );
    });
  });

  test('hukum tajwid di kurikulum dikenali', () {
    expect(TajweedRule.fromProviderClass('ikhafa'), isNotNull);
  });
}
