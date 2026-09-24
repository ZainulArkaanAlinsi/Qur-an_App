// Membangun assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json.
//
// Anotasi cpfair/quran-tajweed (CC BY 4.0) memakai indeks huruf pada salinan
// teks Tanzil 2017 tanpa tanda waqaf. Teks aplikasi (Tanzil Uthmani 1.0.2)
// sama persis dengan salinan itu ditambah tanda waqaf, tanda sajdah, tanda
// rub' hizb, dan spasi pengiringnya. Skrip ini memetakan ulang setiap indeks
// ke teks aplikasi. Teks ayat sendiri tidak diubah sedikit pun.
//
// Pemakaian:
//   dart run tool/build_tajweed_asset.dart <cpfair.json> <quran-uthmani-2017.txt>
//
// Sumber:
//   https://github.com/cpfair/quran-tajweed (output/tajweed.hafs.uthmani-pause-sajdah.json)
//   https://github.com/cpfair/quran-tajweed/files/7281388/quran-uthmani.txt
import 'dart:convert';
import 'dart:io';

const _ours = 'assets/quran/raw/tanzil_uthmani_v1.0.2.txt';
const _out = 'assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json';

/// Huruf yang hanya ada di teks aplikasi: tanda waqaf, rub' hizb, sajdah,
/// dan spasi. Huruf lain yang berbeda berarti teksnya tidak cocok.
bool _skippable(int rune) =>
    rune == 0x20 || (rune >= 0x06D6 && rune <= 0x06DE) || rune == 0x06E9;

List<String> _verses(String path) {
  final lines = File(path)
      .readAsLinesSync()
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .map((l) {
        // Salinan 2017 berformat "surah|ayat|teks".
        final parts = l.split('|');
        return parts.length == 3 ? parts[2] : l;
      })
      .toList();
  if (lines.length != 6236) {
    throw StateError('$path: ${lines.length} ayat, bukan 6236.');
  }
  return lines;
}

/// Indeks rune pada [ours] untuk tiap rune pada [theirs].
List<int> _map(List<int> ours, List<int> theirs, int verse) {
  final result = <int>[];
  var i = 0;
  for (final rune in theirs) {
    while (i < ours.length && ours[i] != rune) {
      if (!_skippable(ours[i])) {
        throw StateError(
          'Ayat ke-${verse + 1}: huruf U+${ours[i].toRadixString(16)} '
          'tidak ada di salinan cpfair.',
        );
      }
      i++;
    }
    if (i >= ours.length) throw StateError('Ayat ke-${verse + 1} tidak cocok.');
    result.add(i++);
  }
  return result;
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'dart run tool/build_tajweed_asset.dart <cpfair.json> <quran-uthmani.txt>',
    );
    exit(64);
  }
  final ours = _verses(_ours);
  final theirs = _verses(args[1]);
  final data = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  if (data.length != 6236) throw StateError('cpfair: ${data.length} ayat.');

  final rules = <String>[];
  final verses = <List<int>>[];
  for (var v = 0; v < 6236; v++) {
    final ourRunes = ours[v].runes.toList();
    final map = _map(ourRunes, theirs[v].runes.toList(), v);
    final flat = <int>[];
    for (final note in (data[v]['annotations'] as List).cast<Map>()) {
      final rule = note['rule'] as String;
      var index = rules.indexOf(rule);
      if (index < 0) {
        rules.add(rule);
        index = rules.length - 1;
      }
      final start = note['start'] as int;
      final end = note['end'] as int;
      // Rentang [start, end) dipetakan lewat huruf pertama dan terakhirnya.
      flat.addAll([index, map[start], map[end - 1] + 1]);
    }
    verses.add(flat);
  }

  File(_out).writeAsStringSync(
    jsonEncode({
      'source':
          'cpfair/quran-tajweed output/tajweed.hafs.uthmani-pause-sajdah.json',
      'license': 'CC BY 4.0',
      'text': 'tanzil_uthmani_v1.0.2.txt',
      'note':
          'Indeks rune dipetakan ulang ke teks Tanzil 1.0.2; teks tidak diubah.',
      'rules': rules,
      'verses': verses,
    }),
  );
  stdout.writeln('Tersimpan $_out (${rules.length} hukum).');
}
