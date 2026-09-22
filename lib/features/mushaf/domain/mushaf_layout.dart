/// Model halaman mushaf berbasis baris (bukan ayat) dan penyusunnya.
///
/// Data kata berasal dari satu edisi layout (QCF V2 / V4, Mushaf Madinah
/// 604 halaman). Baris judul surah dan basmalah tidak ada di data kata, jadi
/// posisinya diturunkan: tepat sebelum baris pertama ayat 1 sebuah surah —
/// judul lalu basmalah, atau judul saja untuk Al-Fatihah (basmalah = ayat 1)
/// dan At-Taubah — dan boleh jatuh ke akhir halaman sebelumnya. Aturan ini
/// diaudit pada 604 halaman (22 September 2026) tanpa baris hilang/bentrok.
///
/// Penyusun bersifat gagal-tertutup: baris hilang, bentrok, di luar rentang,
/// atau urutan kata yang mundur melempar [MushafLayoutException] alih-alih
/// menampilkan halaman tebakan.
library;

const mushafPageCount = 604;

/// Halaman 1–2 berisi 8 baris di tengah; halaman lain 15 baris.
int mushafLineCount(int page) => page <= 2 ? 8 : 15;

class MushafWord {
  const MushafWord({
    required this.id,
    required this.page,
    required this.line,
    required this.surah,
    required this.ayah,
    required this.position,
    required this.isVerseEnd,
    required this.glyph,
  });

  final int id;
  final int page;
  final int line;
  final int surah;
  final int ayah;

  /// Urutan dalam ayat; penanda akhir ayat adalah posisi terakhir.
  final int position;
  final bool isVerseEnd;

  /// Kode glyph QCF (`code_v2`); hanya bermakna dengan font halaman [page].
  final String glyph;

  String get verseKey => '$surah:$ayah';

  int _compareReading(MushafWord other) {
    if (surah != other.surah) return surah - other.surah;
    if (ayah != other.ayah) return ayah - other.ayah;
    return position - other.position;
  }
}

sealed class MushafLine {
  const MushafLine(this.number);

  final int number;
}

final class MushafTextLine extends MushafLine {
  const MushafTextLine(super.number, this.words);

  /// Urut sesuai bacaan (kanan ke kiri).
  final List<MushafWord> words;
}

final class MushafSurahHeader extends MushafLine {
  const MushafSurahHeader(super.number, this.surah);

  final int surah;
}

final class MushafBasmalah extends MushafLine {
  const MushafBasmalah(super.number, this.surah);

  final int surah;
}

class MushafPage {
  const MushafPage(this.number, this.lines);

  final int number;
  final List<MushafLine> lines;

  bool get isOpeningPage => number <= 2;

  /// Kunci ayat pada halaman ini sesuai urutan bacaan, tanpa duplikat.
  List<String> get verseKeys {
    final keys = <String>[];
    for (final line in lines) {
      if (line is! MushafTextLine) continue;
      for (final word in line.words) {
        if (keys.isEmpty || keys.last != word.verseKey) keys.add(word.verseKey);
      }
    }
    return keys;
  }

  /// Surah yang teksnya muncul di halaman ini.
  List<int> get surahs => {
        for (final key in verseKeys) int.parse(key.split(':').first),
      }.toList();
}

class MushafLayoutException implements Exception {
  const MushafLayoutException(this.page, this.message);

  final int page;
  final String message;

  @override
  String toString() => 'Layout halaman $page tidak valid: $message';
}

/// Menyusun halaman [page] dari [words]. [words] harus memuat semua kata
/// halaman [page] dan halaman berikutnya (untuk judul surah yang tumpah ke
/// akhir halaman ini); kata dari halaman lain diabaikan, duplikat id dibuang.
MushafPage buildMushafPage(int page, Iterable<MushafWord> words) {
  if (page < 1 || page > mushafPageCount) {
    throw MushafLayoutException(page, 'nomor halaman di luar 1–604');
  }
  final unique = <int, MushafWord>{};
  for (final word in words) {
    if (word.page == page || word.page == page + 1) unique[word.id] = word;
  }

  // Posisi (halaman, baris) paling awal ayat 1 setiap surah.
  final starts = <int, (int, int)>{};
  for (final word in unique.values) {
    if (word.ayah != 1) continue;
    final current = starts[word.surah];
    if (current == null ||
        word.page < current.$1 ||
        (word.page == current.$1 && word.line < current.$2)) {
      starts[word.surah] = (word.page, word.line);
    }
  }

  (int, int) previous((int, int) slot) => slot.$2 > 1
      ? (slot.$1, slot.$2 - 1)
      : (slot.$1 - 1, mushafLineCount(slot.$1 - 1));

  final derived = <int, MushafLine>{};
  void place((int, int) slot, MushafLine Function(int) line) {
    if (slot.$1 != page) return;
    if (derived.containsKey(slot.$2)) {
      throw MushafLayoutException(page, 'baris ${slot.$2} diturunkan ganda');
    }
    derived[slot.$2] = line(slot.$2);
  }

  for (final MapEntry(key: surah, value: start) in starts.entries) {
    final before = previous(start);
    if (surah == 1 || surah == 9) {
      place(before, (n) => MushafSurahHeader(n, surah));
    } else {
      place(before, (n) => MushafBasmalah(n, surah));
      place(previous(before), (n) => MushafSurahHeader(n, surah));
    }
  }

  final byLine = <int, List<MushafWord>>{};
  for (final word in unique.values) {
    if (word.page == page) byLine.putIfAbsent(word.line, () => []).add(word);
  }

  final count = mushafLineCount(page);
  final outside = [...byLine.keys, ...derived.keys]
      .where((n) => n < 1 || n > count);
  if (outside.isNotEmpty) {
    throw MushafLayoutException(page, 'baris di luar 1–$count: $outside');
  }

  final lines = <MushafLine>[];
  MushafWord? lastWord;
  for (var n = 1; n <= count; n++) {
    final text = byLine[n];
    final slot = derived[n];
    if (text != null && slot != null) {
      throw MushafLayoutException(page, 'baris $n berisi teks dan judul');
    }
    if (slot != null) {
      lines.add(slot);
      continue;
    }
    if (text == null) {
      throw MushafLayoutException(page, 'baris $n kosong');
    }
    text.sort((a, b) => a._compareReading(b));
    if (lastWord != null && text.first._compareReading(lastWord) <= 0) {
      throw MushafLayoutException(
        page,
        'urutan kata mundur di baris $n (${text.first.verseKey})',
      );
    }
    lastWord = text.last;
    lines.add(MushafTextLine(n, List.unmodifiable(text)));
  }
  return MushafPage(page, List.unmodifiable(lines));
}
