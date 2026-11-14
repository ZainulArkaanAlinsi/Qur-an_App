// Header Reader yang menempel di atas daftar ayat harus punya latar solid.
//
// Temuan 14 November 2026 di emulator: pil "Indonesia / Tajwid" dan baris
// petunjuk "Ketuk huruf berwarna untuk melihat artinya." melayang di atas
// daftar tanpa latar apa pun. Saat ayat tergulir di bawahnya (mis. murottal
// yang mengikuti bacaan, atau menggulir ke atas), teks Arab tembus dan
// bertumpuk dengan tulisan petunjuk sehingga sulit dibaca.
//
// Satu tes saja, mengikuti reader_screen_test.dart: future repositori teks
// dibuat di zona waktu semu sehingga tidak bisa dipakai ulang antar tes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pil filter dan petunjuk tajwid berlatar solid selebar layar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    const width = 420.0;
    await tester.binding.setSurfaceSize(const Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() => QuranTextRepository.instance.versesForSurah(1));
    await tester.runAsync(() => TranslationRepository.instance.forSurah(1));
    await tester.runAsync(() => TajweedRepository.instance.forSurah(1));

    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: ReaderScreen(surah: surahCatalog.first),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    // Petunjuk tampil pada pemakaian pertama; tanpa itu tes ini tidak bermakna.
    expect(find.byType(TajweedHint), findsOneWidget);
    expect(find.byType(ReaderChips), findsOneWidget);

    final tokens = SacredTheme.tokensFor(AppPalette.sacred, Brightness.light);

    // Cari blok ColoredBox berlatar halaman yang memuat KEDUANYA.
    final blocks = tester.widgetList<ColoredBox>(
      find.ancestor(
        of: find.byType(TajweedHint),
        matching: find.byType(ColoredBox),
      ),
    );
    final candidates = find
        .ancestor(
          of: find.byType(TajweedHint),
          matching: find.byType(ColoredBox),
        )
        .evaluate()
        .where((e) {
          final box = e.widget as ColoredBox;
          return box.color == tokens.bg &&
              find
                  .descendant(
                    of: find.byWidget(box),
                    matching: find.byType(ReaderChips),
                  )
                  .evaluate()
                  .isNotEmpty;
        })
        .toList();
    expect(
      candidates,
      isNotEmpty,
      reason:
          'ReaderChips dan TajweedHint harus berada di dalam satu ColoredBox '
          'berwarna tokens.bg (ditemukan ${blocks.length} ColoredBox leluhur '
          'tanpa kecocokan).',
    );

    final size = (candidates.first.renderObject! as RenderBox).size;
    expect(size.width, width, reason: 'latar harus selebar layar');
    expect(
      size.height,
      lessThan(200),
      reason: 'yang diberi latar hanya blok header, bukan seluruh halaman',
    );
  });
}
