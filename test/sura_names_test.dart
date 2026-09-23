import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';

void main() {
  final xml = File('assets/quran/raw/quran-data.xml').readAsStringSync();

  test('metadata Tanzil memuat 114 nama surah berurutan', () {
    final names = SuraNamesRepository.parse(xml);
    expect(names, hasLength(114));
    // Nama dipakai apa adanya; yang diperiksa hanya bahwa isinya huruf Arab
    // dan tidak kosong, bukan ejaannya yang diketik ulang di sini.
    for (final name in names) {
      expect(name.trim(), isNotEmpty);
      expect(name.runes.first, greaterThanOrEqualTo(0x0600));
    }
  });

  test('daftar yang kurang ditolak, bukan dipakai separuh', () {
    expect(
      () => SuraNamesRepository.parse('<sura index="1" ayas="7" name="x" />'),
      throwsFormatException,
    );
  });
}
