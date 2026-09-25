import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';

/// Kata-kata ayat contoh dengan penomoran yang sama persis dengan mushaf:
/// basmalah bawaan Tanzil di awal ayat 1 dibuang lewat [basmalahPrefix], dan
/// tanda waqaf/sajdah ikut kata sebelumnya ([tanzilWords]).
/// [fatihahFirst] adalah ayat 1:1 dari dataset yang sama.
List<TanzilWord> exampleWords({
  required int surah,
  required int ayah,
  required String verse,
  required String fatihahFirst,
}) => tanzilWords(
  verse,
  from: ayah == 1 ? basmalahPrefix(surah, verse, fatihahFirst) : 0,
);

/// Rentang teks kata `[dari, sampai]` (1-based, inklusif) pada [all], atau
/// null bila rentangnya tidak ada atau di luar jangkauan ayat.
TanzilWord? highlightOf(List<TanzilWord> all, List<int>? words) {
  if (words == null || words.length != 2) return null;
  final from = words[0];
  final to = words[1];
  if (from < 1 || to < from || to > all.length) return null;
  return TanzilWord(all[from - 1].start, all[to - 1].end);
}
