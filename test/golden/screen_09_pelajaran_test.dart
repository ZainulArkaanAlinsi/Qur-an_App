import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Data uji yang meniru V2-Pelajaran.png. Ini bukan materi aplikasi:
/// materi asli ditulis dan ditinjau manusia di assets/learn/curriculum.json.
const _fixture = Lesson(
  id: 'uji-huruf',
  level: 1,
  order: 1,
  title: 'Huruf hijaiyah',
  summary: 'Dua puluh delapan huruf, nama, dan bunyinya.',
  objectives: [],
  review: ContentReviewStatus.published,
  provenance: 'Data uji golden.',
  sources: [],
  blocks: [
    LessonText('Huruf hijaiyah ada 28.'),
    LessonText(
      'Bentuk dasarnya sama. Yang membedakan hanya '
      '**jumlah dan letak titiknya**.',
      heading: 'Huruf yang mirip',
    ),
    LessonLetters([
      LessonLetter(letter: 'ب', name: 'Ba', note: '1 titik di bawah'),
      LessonLetter(letter: 'ت', name: 'Ta', note: '2 titik di atas'),
      LessonLetter(letter: 'ث', name: 'Tsa', note: '3 titik di atas'),
    ]),
    LessonAudio(label: 'Bunyi ba, ta, tsa', asset: null),
    LessonQuiz(
      id: 'uji-1',
      question: 'Mana huruf Ta?',
      options: ['ث', 'ت', 'ب'],
      answer: 1,
      explanation: 'Ta punya dua titik di atas.',
    ),
  ],
);

Future<void> _seed(int step) async {
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService.init();
  await SharedPreferencesService.setLessonStep(_fixture.id, step);
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('09 pelajaran · bacaan · ${variant.suffix}', (tester) async {
      await tester.runAsync(() => _seed(1));
      await pumpGolden(
        tester,
        const LessonScreen(lesson: _fixture, quizRound: 1),
        variant: variant,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Huruf yang mirip'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expectNotTruncated(tester, ['Lanjut', 'Ba', 'Ta', 'Tsa']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/09_pelajaran_${variant.suffix}.png'),
      );
    });
  }

  testWidgets('09 pelajaran · latihan dijawab benar', (tester) async {
    await tester.runAsync(() => _seed(2));
    await pumpGolden(
      tester,
      const LessonScreen(lesson: _fixture, quizRound: 1),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mana huruf Ta?'), findsOneWidget);
    await tester.tap(find.text('ت'));
    await tester.pumpAndSettle();
    expect(find.text('Benar — Ta punya dua titik di atas.'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/09_pelajaran_latihan_light.png'),
    );
  });
}
