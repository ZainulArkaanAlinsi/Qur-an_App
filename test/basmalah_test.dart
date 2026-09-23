import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';

/// Basmalah tampil persis seperti dataset: Al-Fatihah memuatnya sebagai ayat
/// pertama, At-Taubah tidak memuatnya, dan An-Naml 27:30 memuatnya di dalam
/// badan ayat. Aplikasi tidak boleh menambah atau membuangnya.
///
/// Teksnya diambil dari dataset, tidak diketik ulang di sini: menulis sendiri
/// satu harakat yang berbeda sudah cukup membuat perbandingannya meleset.
void main() {
  // Membaca aset butuh binding, meski ini bukan tes widget.
  TestWidgetsFlutterBinding.ensureInitialized();

  late String basmalah;

  setUpAll(() async {
    basmalah = (await QuranTextRepository.instance.versesForSurah(1)).first;
  });

  test('ayat pertama Al-Fatihah memang basmalah', () async {
    final verses = await QuranTextRepository.instance.versesForSurah(1);
    expect(verses, hasLength(7));
    // Buktinya tanpa mengetik ulang: kalimat yang sama muncul di An-Naml 27:30.
    final anNaml = await QuranTextRepository.instance.versesForSurah(27);
    expect(anNaml[29], contains(basmalah));
  });

  test('At-Taubah dibuka tanpa basmalah', () async {
    final verses = await QuranTextRepository.instance.versesForSurah(9);
    expect(verses.first.contains(basmalah), isFalse);
  });

  test(
    'An-Naml 27:30 memuat basmalah di dalam ayat, bukan sebagai ayat',
    () async {
      final verses = await QuranTextRepository.instance.versesForSurah(27);
      expect(verses[29], isNot(basmalah));
      expect(verses[29].length, greaterThan(basmalah.length));
    },
  );

  test('hanya Al-Fatihah yang memakai basmalah sebagai ayat utuh', () async {
    final whole = <int>[];
    for (var surah = 1; surah <= 114; surah++) {
      final verses = await QuranTextRepository.instance.versesForSurah(surah);
      if (verses.first == basmalah) whole.add(surah);
    }
    expect(whole, [1]);
  });
}
