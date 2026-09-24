/// Teks Tanzil yang ditempatkan ke baris halaman mushaf.
///
/// Susunan baris datang dari data layout ([MushafPage]); isi setiap kata
/// adalah potongan teks ayat Tanzil, tidak diketik ulang dan tidak diubah.
/// Offset kata dipakai langsung untuk warna tajwid cpfair (yang diindeks pada
/// teks ayat Tanzil yang sama).
library;

import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

/// Rentang satu kata pada teks ayat: `[start, end)`.
class TanzilWord {
  const TanzilWord(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TanzilWord && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TanzilWord($start, $end)';
}

/// Tanda waqaf, tanda sajdah, dan rub' hizb: bukan kata, menumpang pada kata
/// di sekitarnya.
bool _isMark(String token) =>
    token.isNotEmpty &&
    token.runes.every(
      (r) => (r >= 0x06D6 && r <= 0x06DE) || r == 0x06E9 || r == 0x06ED,
    );

/// Kata-kata [verse] mulai offset [from]. Tanda waqaf/sajdah ikut kata
/// sebelumnya; tanda rub' hizb di awal ayat ikut kata sesudahnya. Hasilnya
/// sejajar dengan penomoran kata QF (posisi 1 = kata pertama).
List<TanzilWord> tanzilWords(String verse, {int from = 0}) {
  final words = <TanzilWord>[];
  int? pendingStart;
  var i = from;
  while (i < verse.length) {
    while (i < verse.length && verse.codeUnitAt(i) == 0x20) {
      i++;
    }
    if (i >= verse.length) break;
    var j = i;
    while (j < verse.length && verse.codeUnitAt(j) != 0x20) {
      j++;
    }
    final token = verse.substring(i, j);
    if (_isMark(token)) {
      if (words.isEmpty) {
        pendingStart ??= i;
      } else {
        words[words.length - 1] = TanzilWord(words.last.start, j);
      }
    } else {
      words.add(TanzilWord(pendingStart ?? i, j));
      pendingStart = null;
    }
    i = j;
  }
  return words;
}

sealed class MushafItem {
  const MushafItem(this.surah, this.ayah);

  final int surah;
  final int ayah;

  String get verseKey => '$surah:$ayah';
}

/// Satu kata: potongan teks ayat pada [range].
final class MushafWordItem extends MushafItem {
  const MushafWordItem(super.surah, super.ayah, this.range);

  final TanzilWord range;
}

/// Penanda akhir ayat (rosette bernomor).
final class MushafVerseEnd extends MushafItem {
  const MushafVerseEnd(super.surah, super.ayah);
}

sealed class MushafRow {
  const MushafRow();
}

final class MushafHeaderRow extends MushafRow {
  const MushafHeaderRow(this.surah);

  final int surah;
}

final class MushafBasmalahRow extends MushafRow {
  const MushafBasmalahRow(this.surah);

  final int surah;
}

final class MushafTextRow extends MushafRow {
  const MushafTextRow(this.items, {this.centered = false});

  final List<MushafItem> items;

  /// Rata tengah (halaman pembuka); baris lain rata kanan-kiri.
  final bool centered;
}

/// Halaman siap tampil: baris-baris beserta teks ayat Tanzil yang dipakai.
class MushafComposedPage {
  const MushafComposedPage({
    required this.number,
    required this.rows,
    required this.verses,
    required this.fatihahFirst,
  });

  final int number;
  final List<MushafRow> rows;

  /// Teks ayat Tanzil per `surah:ayat`, persis dataset.
  final Map<String, String> verses;

  /// Ayat 1:1 (basmalah) dari dataset, untuk baris basmalah.
  final String fatihahFirst;

  String textOf(MushafWordItem word) =>
      verses[word.verseKey]!.substring(word.range.start, word.range.end);

  /// Surah yang teksnya ada di halaman ini, urut bacaan.
  List<int> get surahs => {
    for (final row in rows)
      if (row is MushafTextRow)
        for (final item in row.items) item.surah,
  }.toList();

  /// Kata pertama yang ada di halaman ini.
  MushafItem? get firstItem {
    for (final row in rows) {
      if (row is MushafTextRow && row.items.isNotEmpty) return row.items.first;
    }
    return null;
  }
}

/// Menyusun halaman [page] dengan teks Tanzil. [verses] berisi ayat-ayat
/// setiap surah di halaman (indeks 0 = ayat 1), [fatihahFirst] ayat 1:1.
///
/// Gagal-tertutup: kata yang posisinya tidak ada di teks Tanzil, atau penanda
/// akhir ayat yang mendahului kata terakhir ayat itu, melempar
/// [MushafLayoutException].
MushafComposedPage composeMushafPage(
  MushafPage page,
  Map<int, List<String>> verses,
  String fatihahFirst,
) {
  final texts = <String, String>{};
  final words = <String, List<TanzilWord>>{};
  List<TanzilWord> wordsOf(int surah, int ayah) {
    final key = '$surah:$ayah';
    return words.putIfAbsent(key, () {
      final list = verses[surah];
      if (list == null || ayah < 1 || ayah > list.length) {
        throw MushafLayoutException(page.number, 'teks $key tidak ada');
      }
      final text = list[ayah - 1];
      texts[key] = text;
      final from = ayah == 1 ? basmalahPrefix(surah, text, fatihahFirst) : 0;
      return tanzilWords(text, from: from);
    });
  }

  final rows = <MushafRow>[];
  final lastPosition = <String, int>{};
  for (final line in page.lines) {
    switch (line) {
      case MushafSurahHeader(:final surah):
        rows.add(MushafHeaderRow(surah));
      case MushafBasmalah(:final surah):
        rows.add(MushafBasmalahRow(surah));
      case MushafTextLine(words: final lineWords):
        final items = <MushafItem>[];
        for (final word in lineWords) {
          final list = wordsOf(word.surah, word.ayah);
          if (word.isVerseEnd) {
            final seen = lastPosition[word.verseKey];
            if (seen != null && seen != list.length) {
              throw MushafLayoutException(
                page.number,
                'akhir ${word.verseKey} setelah kata $seen dari '
                '${list.length}',
              );
            }
            items.add(MushafVerseEnd(word.surah, word.ayah));
          } else {
            if (word.position < 1 || word.position > list.length) {
              throw MushafLayoutException(
                page.number,
                'kata ${word.position} dari ${word.verseKey} tidak ada di '
                'teks (${list.length} kata)',
              );
            }
            lastPosition[word.verseKey] = word.position;
            items.add(
              MushafWordItem(word.surah, word.ayah, list[word.position - 1]),
            );
          }
        }
        rows.add(MushafTextRow(items, centered: page.isOpeningPage));
    }
  }
  return MushafComposedPage(
    number: page.number,
    rows: List.unmodifiable(rows),
    verses: Map.unmodifiable(texts),
    fatihahFirst: fatihahFirst,
  );
}
