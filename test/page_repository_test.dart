import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/page_repository.dart';

void main() {
  final xml = File('assets/quran/raw/quran-data.xml').readAsStringSync();

  test('metadata Tanzil memuat 604 halaman berurutan', () {
    final pages = PageRepository.parse(xml);
    expect(pages, hasLength(604));
    expect(pages.first.surah, 1);
    expect(pages.first.verse, 1);
    // Halaman 2 mulai di Al-Baqarah, sesuai mushaf Madinah.
    expect(pages[1].surah, 2);
    expect(pages[1].verse, 1);
    expect(pages.last.number, 604);
  });

  test('metadata yang kurang ditolak, bukan dipakai separuh', () {
    expect(
      () => PageRepository.parse('<page index="1" sura="1" aya="1" />'),
      throwsFormatException,
    );
  });

  test('halaman yang melompat mundur ditolak', () {
    final broken = xml.replaceFirst(
      '<page index="3" sura="2" aya="6" />',
      '<page index="3" sura="1" aya="1" />',
    );
    expect(() => PageRepository.parse(broken), throwsFormatException);
  });
}
