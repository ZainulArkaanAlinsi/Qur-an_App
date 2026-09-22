// Audit dump penuh `text_uthmani_tajweed` terhadap parser whitelist.
//
// Pemakaian (dump tidak dibundel/di-commit karena lisensi provider):
//   dart run tool/tajweed_audit.dart path/ke/uthmani_tajweed.json
//
// Format dump: {"verses":[{"verse_key":"1:1","text_uthmani_tajweed":"..."}]}
// Keluar dengan kode 1 bila ada ayat yang gagal diparse, class asing, atau
// teks polos yang berbeda dari markup tanpa tag.
import 'dart:convert';
import 'dart:io';

import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Pemakaian: dart run tool/tajweed_audit.dart <dump.json>');
    exit(64);
  }
  final json = jsonDecode(File(args.single).readAsStringSync()) as Map;
  final verses = json['verses'] as List;
  const parser = TajweedMarkupParser();
  final counts = <TajweedRule, int>{};
  final rejected = <String, int>{};
  final failures = <String>[];
  var nested = 0;

  for (final raw in verses) {
    final key = raw['verse_key'] as String;
    final markup = raw['text_uthmani_tajweed'] as String;
    try {
      final verse = parser.parse(key, markup);
      final stripped = markup
          .replaceAll(RegExp(r'<span class=end>.*?</span>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), '');
      if (verse.text != stripped) failures.add('$key: teks polos berbeda');
      if (verse.endMarker == null) failures.add('$key: tanpa nomor ayat');
      for (final entry in verse.ruleCounts.entries) {
        counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
      }
      for (final cls in verse.rejectedClasses) {
        rejected[cls] = (rejected[cls] ?? 0) + 1;
      }
      if (verse.segments.any((s) => s.depth > 0)) nested++;
    } on FormatException catch (error) {
      failures.add('$key: ${error.message}');
    }
  }

  stdout.writeln('Ayat: ${verses.length}, dengan tag bersarang: $nested');
  for (final rule in TajweedRule.values) {
    stdout.writeln('  ${rule.providerClass.padRight(22)} ${counts[rule] ?? 0}');
  }
  if (rejected.isNotEmpty) stdout.writeln('Class ditolak: $rejected');
  for (final failure in failures.take(20)) {
    stdout.writeln('GAGAL $failure');
  }
  final ok = failures.isEmpty && rejected.isEmpty;
  stdout.writeln(ok ? 'OK' : 'GAGAL: ${failures.length} ayat');
  exit(ok ? 0 : 1);
}
