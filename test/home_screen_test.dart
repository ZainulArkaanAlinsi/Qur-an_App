import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(WidgetTester tester, {VoidCallback? onOpenQuran}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Teks Al-Qur'an diurai lewat compute(), dan isolate tidak berjalan di bawah
  // waktu semu; muat sekali di waktu nyata agar hasilnya sudah tersimpan.
  await tester.runAsync(() async {
    await QuranTextRepository.instance.versesForSurah(1);
    await TranslationRepository.instance.forSurah(1);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
      home: Scaffold(body: HomeScreen(
          onOpenQuran: onOpenQuran ?? () {},
          onOpenLearn: () {},
        )),
    ),
  );
  await tester.pump();
  // Pembacaan aset dan permintaan jaringan hanya berjalan di luar waktu semu,
  // dan beranda merangkai beberapa pembacaan, jadi beri beberapa putaran.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_read_surah': 36,
      'last_read_verse_36': 41,
    });
    await SharedPreferencesService.init();
  });

  // Repositori teks menyimpan hasil urainya, dan future yang dibuat di zona
  // waktu semu tes pertama tidak selesai lagi di tes berikutnya. Karena itu
  // semua yang bergantung pada dataset diperiksa dalam satu tes.
  testWidgets('beranda menampilkan data perangkat, bukan angka contoh', (
    tester,
  ) async {
    await _pumpHome(tester);

    final surah = surahCatalog[35];
    expect(find.text(surah.displayName), findsOneWidget);
    expect(
      find.text('Ayat 41 dari ${surah.ayahCount} · Juz 23'),
      findsOneWidget,
    );
    // 41/83 = 49,4% -> dibulatkan 49%.
    expect(find.text('49%'), findsOneWidget);

    // Jadwal salat tidak bisa diambil di tes; keadaannya harus diakui.
    expect(find.text('Jadwal salat butuh koneksi internet.'), findsOneWidget);
    expect(find.text('Kalender Hijriah butuh koneksi'), findsOneWidget);

    expect(find.text('AYAT HARI INI'), findsOneWidget);
    final reference = find.textContaining('QS. ');
    expect(reference, findsOneWidget);

    // Teksnya harus sama persis dengan dataset, bukan ditulis ulang.
    final label = tester.widget<Text>(reference).data!;
    final match = RegExp(r'QS\. (.+) \d+:(\d+)').firstMatch(label)!;
    final chosen = surahCatalog.firstWhere(
      (item) => item.displayName == match[1],
    );
    final verses = await tester.runAsync(
      () => QuranTextRepository.instance.versesForSurah(chosen.number),
    );
    expect(find.text(verses![int.parse(match[2]!) - 1]), findsOneWidget);
  });

  testWidgets('pintasan Surah membuka tab Qur’an', (tester) async {
    var opened = 0;
    await _pumpHome(tester, onOpenQuran: () => opened++);

    await tester.tap(find.text('Surah'));
    await tester.pump();
    expect(opened, 1);
  });
}
