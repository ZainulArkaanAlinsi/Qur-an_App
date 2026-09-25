import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Materi tajwid v3 (docs/design/v3/screens/18-materi-nun-sukun.md) dengan
/// isi asli curriculum.json tahap 10: halaman Idgham bighunnah, Pengecualian
/// izhar mutlak, Ikhfa (grid 15 huruf + daftar ringkas 15 contoh), dan
/// lembar kartu ayat lengkap.
void main() {
  late Lesson lesson;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    final curriculum = await CurriculumRepository.load();
    lesson = curriculum.lessons.firstWhere(
      (item) => item.id == 'nun-sukun-tanwin',
    );
    // Dataset dimuat sekali di luar waktu semu; layar memakai cache-nya.
    final surahs = {
      for (final block in lesson.blocks)
        if (block is LessonExample) block.surah,
    };
    await QuranTextRepository.instance.versesForSurah(1);
    for (final surah in surahs) {
      await QuranTextRepository.instance.versesForSurah(surah);
      await TajweedRepository.instance.forSurah(surah);
    }
  });

  int pageOf(String heading) => lesson.pages.indexWhere(
    (page) => page.whereType<LessonText>().first.heading == heading,
  );

  Future<void> open(
    WidgetTester tester,
    String heading,
    GoldenVariant variant,
  ) async {
    // Langkah tersimpan adalah yang terjauh, jadi mulai dari data kosong.
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
      await SharedPreferencesService.setLessonStep(lesson.id, pageOf(heading));
    });
    await pumpGolden(
      tester,
      LessonScreen(lesson: lesson, quizRound: 1),
      variant: variant,
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  for (final variant in GoldenVariant.all) {
    testWidgets('18 materi · idgham bighunnah · ${variant.suffix}', (
      tester,
    ) async {
      await open(tester, '2. Idgham bighunnah', variant);
      expect(tester.takeException(), isNull);
      expect(find.text('2. Idgham bighunnah'), findsOneWidget);
      expect(find.text('DRAF'), findsOneWidget);
      expect(find.text('Memuat ayat…'), findsNothing);
      // Kartu huruf ya dan mim: ekornya tidak menimpa nama huruf.
      // Di teks 2× kartu huruf ada di bawah lipatan; periksa di 1×.
      for (final name in variant.textScale == 1 ? ['Ya', 'Mim'] : <String>[]) {
        final glyph = name == 'Ya' ? 'ي' : 'م';
        final letter = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == glyph &&
              widget.style?.fontSize == 42,
        );
        expect(
          tester.getBottomLeft(letter).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text(name)).dy + .5),
          reason: 'kotak glyph $name berakhir sebelum namanya',
        );
      }
      expectNotTruncated(tester, ['Lanjut', 'Ya', 'Nun', 'Mim', 'Wau']);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/18_materi_idgham_${variant.suffix}.png'),
      );
    });
  }

  testWidgets('18 materi · pengecualian izhar mutlak', (tester) async {
    await open(
      tester,
      'Pengecualian: izhar mutlak',
      const GoldenVariant(Brightness.light, 1),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Al-Baqarah · ayat 85'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/18_materi_mutlak_light.png'),
    );
  });

  for (final scale in [1.0, 2.0]) {
    final variant = GoldenVariant(Brightness.light, scale);
    testWidgets('18 materi · ikhfa 15 huruf + daftar · ${variant.suffix}', (
      tester,
    ) async {
      await open(tester, '5. Ikhfa haqiqi', variant);
      expect(tester.takeException(), isNull, reason: 'grid 15 huruf');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/18_materi_ikhfa_${variant.suffix}.png'),
      );
      // Gulir ke daftar ringkas 15 contoh: tidak boleh overflow.
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'daftar 15 contoh');
      expect(find.textContaining(' · ayat '), findsWidgets);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/18_materi_ikhfa_daftar_${variant.suffix}.png',
        ),
      );
    });
  }

  testWidgets('18 materi · ketuk daftar membuka kartu ayat lengkap', (
    tester,
  ) async {
    await open(
      tester,
      'Pengecualian: izhar mutlak',
      const GoldenVariant(Brightness.light, 1),
    );
    await tester.tap(find.text('Al-Baqarah · ayat 85'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('CONTOH'), findsOneWidget);
    expect(find.text('Al-Baqarah · 85'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/18_materi_kartu_ayat_light.png'),
    );
  });

  // Ayat pendek satu baris (112:1, basmalah bawaan Tanzil dibuang): tetap
  // rata kanan dan kata pertama yang disorot.
  testWidgets('18 materi · kartu contoh ayat pendek', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesService.init();
      await QuranTextRepository.instance.versesForSurah(112);
      await TajweedRepository.instance.forSurah(112);
    });
    const short = Lesson(
      id: 'uji-pendek',
      level: 10,
      order: 1,
      title: 'Uji',
      summary: 'Uji.',
      objectives: [],
      blocks: [
        LessonText('Contoh satu baris.', heading: 'Ayat pendek'),
        LessonExample(
          surah: 112,
          ayah: 1,
          words: [1, 1],
          note: 'Kata pertama disorot.',
        ),
      ],
      sources: [],
      review: ContentReviewStatus.draft,
      provenance: 'Data uji golden.',
    );
    await pumpGolden(tester, const LessonScreen(lesson: short, quizRound: 1));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Memuat ayat…'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/18_materi_ayat_pendek_light.png'),
    );
  });
}
