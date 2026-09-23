import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Repositori teks menyimpan hasil urainya, dan future yang dibuat di zona
  // waktu semu tes pertama tidak selesai lagi di tes berikutnya. Karena itu
  // seluruh pemeriksaan pembaca dijalankan dalam satu tes.
  testWidgets('pembaca menampilkan dataset, posisi, dan mode fokus', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    await tester.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Teks diurai lewat compute(), dan isolate tidak berjalan di waktu semu.
    final verses = await tester.runAsync(
      () => QuranTextRepository.instance.versesForSurah(1),
    );
    final translation = await tester.runAsync(
      () => TranslationRepository.instance.forSurah(1),
    );

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

    // Teks Arab tampil persis dataset (di dalam Text.rich bersama penanda
    // akhir ayat, jadi dicocokkan sebagai bagian dari teks polosnya).
    expect(find.textContaining(verses!.first), findsWidgets);
    expect(find.text(translation!.first), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);

    // Juz dan halaman dari metadata Tanzil, bukan angka contoh.
    expect(find.text('Juz 1 · Hal. 1 · Ayat 1'), findsOneWidget);

    // Selama pemutar diam tidak ada ayat yang disorot.
    final tokens = SacredTheme.tokensFor(AppPalette.sacred, Brightness.light);
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where(
            (item) =>
                (item.decoration as BoxDecoration?)?.color ==
                tokens.primarySoft,
          ),
      isEmpty,
    );

    await tester.tap(find.byTooltip('Mode fokus'));
    await tester.pump();

    expect(find.text(translation.first), findsNothing);
    expect(find.textContaining(verses.first), findsWidgets);
    expect(find.text('Murottal'), findsOneWidget);
    expect(find.text('Terjemahan'), findsOneWidget);

    // Tombol Terjemahan mengembalikan pembaca ke tampilan biasa.
    await tester.tap(find.text('Terjemahan'));
    await tester.pump();
    expect(find.text(translation.first), findsOneWidget);
  });
}
