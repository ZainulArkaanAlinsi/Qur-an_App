/// Pemilih ayat untuk langkah "Temukan di ayat" dan "Dengar & tirukan"
/// (docs/design/v5-sesi-harian/SESI_HARIAN.md §2).
///
/// Semua fungsi di sini murni: masukannya teks Tanzil apa adanya, keluarannya
/// rujukan ayat dan nomor kata. Teks ayat tidak pernah diubah atau
/// dinormalisasi. Pencocokan huruf dan tanda dilakukan persis per code point,
/// dan penyorotan hanya per kata dengan penomoran `tanzilWords()`.
library;

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';

/// Teks ayat Tanzil per surah (indeks 0 = ayat 1), persis dataset.
typedef VerseTexts = Map<int, List<String>>;

/// Ayat pendek: paling banyak 8 kata menurut `tanzilWords()`.
const shortVerseMaxWords = 8;

/// Sumber ayat pendek: Al-Fatihah dan Juz 30 (surah 78–114).
final shortVerseSurahs = List<int>.unmodifiable([
  1,
  for (var surah = 78; surah <= 114; surah++) surah,
]);

/// Satu huruf hijaiyah untuk rotasi "huruf hari ini".
@immutable
class HijaiyahLetter {
  const HijaiyahLetter(this.letter, this.name);

  /// Satu code point, persis seperti di teks Tanzil.
  final String letter;

  /// Nama sesuai urutan di materi tahap 1 (`huruf-hijaiyah`).
  final String name;

  int get codePoint => letter.runes.single;
}

/// 28 huruf hijaiyah dengan urutan dan nama yang sama dengan materi tahap 1
/// ("alif, ba, ta, tsa, … wau, ha, ya"). Hanya bentuk dasarnya: ة, ى, dan
/// hamzah (أ إ ؤ ئ ٱ) tidak disamakan dengan huruf mana pun di sini.
const hijaiyahLetters = <HijaiyahLetter>[
  HijaiyahLetter('ا', 'alif'),
  HijaiyahLetter('ب', 'ba'),
  HijaiyahLetter('ت', 'ta'),
  HijaiyahLetter('ث', 'tsa'),
  HijaiyahLetter('ج', 'jim'),
  HijaiyahLetter('ح', 'ha'),
  HijaiyahLetter('خ', 'kha'),
  HijaiyahLetter('د', 'dal'),
  HijaiyahLetter('ذ', 'dzal'),
  HijaiyahLetter('ر', 'ra'),
  HijaiyahLetter('ز', 'zai'),
  HijaiyahLetter('س', 'sin'),
  HijaiyahLetter('ش', 'syin'),
  HijaiyahLetter('ص', 'shad'),
  HijaiyahLetter('ض', 'dhad'),
  HijaiyahLetter('ط', 'tha'),
  HijaiyahLetter('ظ', 'zha'),
  HijaiyahLetter('ع', "'ain"),
  HijaiyahLetter('غ', 'ghain'),
  HijaiyahLetter('ف', 'fa'),
  HijaiyahLetter('ق', 'qaf'),
  HijaiyahLetter('ك', 'kaf'),
  HijaiyahLetter('ل', 'lam'),
  HijaiyahLetter('م', 'mim'),
  HijaiyahLetter('ن', 'nun'),
  HijaiyahLetter('و', 'wau'),
  HijaiyahLetter('ه', 'ha'),
  HijaiyahLetter('ي', 'ya'),
];

/// Tanda yang dicari di tahap 3–5.
enum VerseMark {
  fathah('fathah', 'berharakat fathah', [0x064E]),
  kasrah('kasrah', 'berharakat kasrah', [0x0650]),
  dhammah('dhammah', 'berharakat dhammah', [0x064F]),
  tanwin('tanwin', 'bertanwin', [0x064B, 0x064C, 0x064D]),
  sukun('sukun', 'bersukun', [0x0652]),
  tasydid('tasydid', 'bertasydid', [0x0651]);

  const VerseMark(this.label, this.adjective, this.codePoints);

  /// Nama tanda, mis. "tanwin".
  final String label;

  /// Dipakai di pertanyaan: "Ketuk kata yang bertanwin."
  final String adjective;

  final List<int> codePoints;
}

/// Apa yang dicari di ayat hari ini: satu huruf atau satu tanda.
@immutable
sealed class VerseFocus {
  const VerseFocus();

  /// Pengenal tersimpan, mis. `huruf:0628` atau `tanda:tanwin`.
  String get id;

  Set<int> get codePoints;

  /// Nama singkat untuk ringkasan, mis. "huruf ب (ba)" atau "tanwin".
  String get label;

  /// Pertanyaan langkah 3.
  String get question;

  /// Kata [word] memuat huruf/tanda ini, dicocokkan persis per code point.
  bool matches(String word) => word.runes.any(codePoints.contains);

  static VerseFocus? fromId(String? id) {
    if (id == null) return null;
    if (id.startsWith('huruf:')) {
      final code = int.tryParse(id.substring(6), radix: 16);
      for (final letter in hijaiyahLetters) {
        if (letter.codePoint == code) return LetterFocus(letter);
      }
      return null;
    }
    if (id.startsWith('tanda:')) {
      final name = id.substring(6);
      for (final mark in VerseMark.values) {
        if (mark.name == name) return MarkFocus(mark);
      }
    }
    return null;
  }
}

final class LetterFocus extends VerseFocus {
  const LetterFocus(this.letter);

  final HijaiyahLetter letter;

  @override
  String get id =>
      'huruf:${letter.codePoint.toRadixString(16).padLeft(4, '0')}';

  @override
  Set<int> get codePoints => {letter.codePoint};

  @override
  String get label => 'huruf ${letter.letter} (${letter.name})';

  @override
  String get question => 'Ketuk kata yang memuat huruf ${letter.letter}.';

  @override
  bool operator ==(Object other) =>
      other is LetterFocus && other.letter.codePoint == letter.codePoint;

  @override
  int get hashCode => letter.codePoint;
}

final class MarkFocus extends VerseFocus {
  const MarkFocus(this.mark);

  final VerseMark mark;

  @override
  String get id => 'tanda:${mark.name}';

  @override
  Set<int> get codePoints => mark.codePoints.toSet();

  @override
  String get label => mark.label;

  @override
  String get question => 'Ketuk kata yang ${mark.adjective}.';

  @override
  bool operator ==(Object other) => other is MarkFocus && other.mark == mark;

  @override
  int get hashCode => mark.hashCode;
}

/// Satu ayat beserta kata-katanya, dengan penomoran yang sama persis dengan
/// mushaf: basmalah bawaan Tanzil di awal ayat 1 dibuang ([basmalahPrefix]),
/// tanda waqaf ikut kata sebelumnya ([tanzilWords]).
@immutable
class VerseWords {
  const VerseWords({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.words,
  });

  final int surah;
  final int ayah;

  /// Teks ayat persis dataset (termasuk awalan basmalah bila ada).
  final String text;

  final List<TanzilWord> words;

  String get key => '$surah:$ayah';

  /// Teks kata ke-[position] (1-based).
  String word(int position) {
    final range = words[position - 1];
    return text.substring(range.start, range.end);
  }
}

/// Kata-kata ayat [surah]:[ayah] dari [texts], atau null bila ayatnya (atau
/// Al-Fatihah ayat 1 untuk memotong basmalah) tidak ada di [texts].
VerseWords? verseWords(VerseTexts texts, int surah, int ayah) {
  final list = texts[surah];
  final fatihah = texts[1];
  if (list == null || ayah < 1 || ayah > list.length) return null;
  if (ayah == 1 && (fatihah == null || fatihah.isEmpty)) return null;
  final text = list[ayah - 1];
  final from = ayah == 1 ? basmalahPrefix(surah, text, fatihah!.first) : 0;
  return VerseWords(
    surah: surah,
    ayah: ayah,
    text: text,
    words: tanzilWords(text, from: from),
  );
}

/// Ayat pendek (≤ [shortVerseMaxWords] kata) dari Al-Fatihah dan Juz 30,
/// urut mushaf. Al-Fatihah ayat 1 (basmalah) tidak ikut.
List<VerseWords> shortVerses(VerseTexts texts) {
  final result = <VerseWords>[];
  for (final surah in shortVerseSurahs) {
    final count = texts[surah]?.length ?? 0;
    for (var ayah = 1; ayah <= count; ayah++) {
      if (surah == 1 && ayah == 1) continue;
      final verse = verseWords(texts, surah, ayah);
      if (verse == null || verse.words.isEmpty) continue;
      if (verse.words.length <= shortVerseMaxWords) result.add(verse);
    }
  }
  return result;
}

/// Nomor kata (1-based, urut) di [verse] yang memuat [focus].
List<int> matchingWords(VerseWords verse, VerseFocus focus) => [
  for (var position = 1; position <= verse.words.length; position++)
    if (focus.matches(verse.word(position))) position,
];

/// Ayat terpilih untuk sesi: rujukan dan kata yang disorot.
@immutable
class VerseChoice {
  const VerseChoice({
    required this.surah,
    required this.ayah,
    required this.words,
    this.focus,
    this.note,
  });

  final int surah;
  final int ayah;

  /// Nomor kata yang disorot (1-based, urut, tidak kosong), sama dengan
  /// penomoran `tanzilWords()`.
  final List<int> words;

  /// Huruf/tanda yang dicari, atau null bila ayat berasal dari contoh
  /// pelajaran yang rentang katanya ditulis penyusun materi.
  final VerseFocus? focus;

  /// Keterangan contoh dari materi, bila ada.
  final String? note;

  String get key => '$surah:$ayah';

  Map<String, dynamic> toJson() => {
    's': surah,
    'a': ayah,
    'w': words,
    if (focus != null) 'f': focus!.id,
    if (note != null) 'n': note,
  };

  /// Gagal tertutup: data rusak menghasilkan null, bukan ayat tebakan.
  static VerseChoice? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final surah = json['s'];
    final ayah = json['a'];
    final words = json['w'];
    final note = json['n'];
    if (surah is! int || ayah is! int || words is! List || words.isEmpty) {
      return null;
    }
    if (words.any((item) => item is! int || item < 1)) return null;
    final focusId = json['f'];
    final focus = focusId is String ? VerseFocus.fromId(focusId) : null;
    if (focusId != null && focus == null) return null;
    return VerseChoice(
      surah: surah,
      ayah: ayah,
      words: List<int>.unmodifiable(words.cast<int>()),
      focus: focus,
      note: note is String ? note : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VerseChoice &&
      other.surah == surah &&
      other.ayah == ayah &&
      listEquals(other.words, words) &&
      other.focus == focus &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(surah, ayah, Object.hashAll(words), focus, note);
}

/// Memilih satu ayat dari [pool] yang memuat [focus].
///
/// - Ayat yang sebagian katanya saja memuat [focus] didahulukan, supaya
///   pertanyaan "Ketuk kata yang …" tidak terjawab dengan sembarang ketuk.
/// - Ayat yang belum ada di [used] didahulukan; [seed] (mis. nomor hari)
///   menentukan titik mulai supaya hasilnya bisa diulang dan diuji.
/// - Bila semua sudah pernah dipakai, dipilih yang paling lama tidak muncul.
///
/// [used] urut lama → baru.
VerseChoice? pickVerse({
  required List<VerseWords> pool,
  required VerseFocus focus,
  required List<String> used,
  required int seed,
}) {
  final all = <(VerseWords, List<int>)>[];
  for (final verse in pool) {
    if (verse.words.length > shortVerseMaxWords) continue;
    final words = matchingWords(verse, focus);
    if (words.isNotEmpty) all.add((verse, words));
  }
  if (all.isEmpty) return null;
  final partial = [
    for (final entry in all)
      if (entry.$2.length < entry.$1.words.length) entry,
  ];
  final candidates = partial.isEmpty ? all : partial;
  final fresh = [
    for (final entry in candidates)
      if (!used.contains(entry.$1.key)) entry,
  ];
  final (verse, words) = fresh.isNotEmpty
      ? fresh[seed.abs() % fresh.length]
      : _leastRecent(candidates, used, (entry) => entry.$1.key);
  return VerseChoice(
    surah: verse.surah,
    ayah: verse.ayah,
    words: List.unmodifiable(words),
    focus: focus,
  );
}

/// Elemen [items] yang paling lama tidak muncul di [used] (urut lama → baru).
T _leastRecent<T>(List<T> items, List<String> used, String Function(T) key) {
  var best = items.first;
  var bestIndex = used.lastIndexOf(key(best));
  for (final item in items.skip(1)) {
    final index = used.lastIndexOf(key(item));
    if (index < bestIndex) {
      best = item;
      bestIndex = index;
    }
  }
  return best;
}

/// Contoh pelajaran yang siap dipakai sesi.
@immutable
class ExampleRef {
  const ExampleRef({
    required this.surah,
    required this.ayah,
    required this.note,
    this.words,
  });

  final int surah;
  final int ayah;
  final String note;

  /// `[dari, sampai]` 1-based inklusif dari materi, atau null.
  final List<int>? words;

  String get key => '$surah:$ayah';
}

/// Memilih satu contoh pelajaran (§2 poin 1 dan 3).
///
/// - Bila [focus] null, hanya contoh yang punya rentang `words` yang dipakai,
///   dan kata yang disorot persis rentang itu.
/// - Bila [focus] ada, kata yang disorot dihitung dari huruf/tandanya; contoh
///   tanpa kata yang cocok dilewati.
/// - Hanya ayat pendek. Contoh yang belum ada di [used] didahulukan.
///   Bila [rotate] true dan semuanya sudah dipakai, dipilih yang paling lama
///   tidak muncul; bila false, hasilnya null (supaya pemanggil mencari ayat
///   Juz 30).
VerseChoice? pickExample({
  required List<ExampleRef> examples,
  required VerseTexts texts,
  required List<String> used,
  VerseFocus? focus,
  bool rotate = true,
}) {
  final usable = <VerseChoice>[];
  final seen = <String>{};
  for (final example in examples) {
    if (!seen.add(example.key)) continue;
    final verse = verseWords(texts, example.surah, example.ayah);
    if (verse == null || verse.words.length > shortVerseMaxWords) continue;
    List<int>? words;
    if (focus != null) {
      words = matchingWords(verse, focus);
    } else if (example.words case [
      final from,
      final to,
    ] when from >= 1 && to >= from && to <= verse.words.length) {
      words = [for (var position = from; position <= to; position++) position];
    }
    if (words == null || words.isEmpty) continue;
    usable.add(
      VerseChoice(
        surah: example.surah,
        ayah: example.ayah,
        words: List.unmodifiable(words),
        focus: focus,
        note: example.note,
      ),
    );
  }
  if (usable.isEmpty) return null;
  for (final choice in usable) {
    if (!used.contains(choice.key)) return choice;
  }
  return rotate
      ? _leastRecent<VerseChoice>(usable, used, (choice) => choice.key)
      : null;
}
