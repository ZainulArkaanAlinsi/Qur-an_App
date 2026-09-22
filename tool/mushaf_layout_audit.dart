// Audit penyusun halaman mushaf terhadap dump penuh 604 halaman.
//
// Pemakaian (dump tidak di-commit karena lisensi provider):
//   dart run tool/mushaf_layout_audit.dart <folder>
//
// <folder> berisi 1.json … 604.json, masing-masing respons
// verses/by_page/{n}?words=true&word_fields=code_v2,line_number,page_number
// &mushaf=1. Keluar dengan kode 1 bila ada halaman yang ditolak.
import 'dart:convert';
import 'dart:io';

import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Pemakaian: dart run tool/mushaf_layout_audit.dart <folder>');
    exit(64);
  }
  final words = <int, MushafWord>{};
  for (var n = 1; n <= mushafPageCount; n++) {
    final json = jsonDecode(File('${args.single}/$n.json').readAsStringSync());
    for (final verse in (json as Map)['verses'] as List) {
      final key = (verse['verse_key'] as String).split(':');
      for (final word in verse['words'] as List) {
        words[word['id'] as int] = MushafWord(
          id: word['id'] as int,
          page: word['page_number'] as int,
          line: word['line_number'] as int,
          surah: int.parse(key[0]),
          ayah: int.parse(key[1]),
          position: word['position'] as int,
          isVerseEnd: word['char_type_name'] == 'end',
          glyph: word['code_v2'] as String,
        );
      }
    }
  }

  final byPage = <int, List<MushafWord>>{};
  for (final word in words.values) {
    byPage.putIfAbsent(word.page, () => []).add(word);
  }
  var headers = 0;
  var basmalahs = 0;
  final failures = <String>[];
  for (var n = 1; n <= mushafPageCount; n++) {
    try {
      final page = buildMushafPage(n, [
        ...?byPage[n],
        ...?byPage[n + 1],
      ]);
      headers += page.lines.whereType<MushafSurahHeader>().length;
      basmalahs += page.lines.whereType<MushafBasmalah>().length;
    } on MushafLayoutException catch (error) {
      failures.add('$error');
    }
  }
  stdout.writeln('Kata: ${words.length}, judul surah: $headers, '
      'basmalah: $basmalahs');
  for (final failure in failures) {
    stdout.writeln('DITOLAK $failure');
  }
  stdout.writeln(failures.isEmpty
      ? 'OK'
      : 'GAGAL: ${failures.length} halaman ditolak');
  exit(failures.isEmpty ? 0 : 1);
}
