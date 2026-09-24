/// Basmalah bawaan teks Tanzil di awal ayat 1.
///
/// Tanzil menyertakan basmalah di awal ayat 1 setiap surah kecuali
/// Al-Fatihah (di sana basmalah adalah ayat 1) dan At-Taubah. Dalam riwayat
/// Hafs basmalah itu bukan bagian ayat, jadi ditampilkan terpisah. Teksnya
/// hanya dipotong, tidak diubah.
library;

/// Panjang awalan basmalah pada ayat 1 (termasuk spasi sesudahnya), atau 0.
/// [fatihahFirst] adalah ayat 1:1 dari dataset yang sama, bukan diketik.
///
/// Di surah 95 dan 97 Tanzil menulis ba basmalah bersyaddah (bekas idgham
/// dari akhir surah sebelumnya). Syaddah itu diabaikan hanya untuk
/// pencocokan; teks yang tampil tetap persis dataset.
int basmalahPrefix(int surah, String firstVerse, String fatihahFirst) {
  if (surah == 1 || surah == 9) return 0;
  final count = fatihahFirst.split(' ').length;
  final words = firstVerse.split(' ');
  if (words.length <= count) return 0;
  final head = words.take(count).join(' ');
  final shaddah = String.fromCharCode(0x0651);
  String bare(String text) => text.replaceAll(shaddah, '');
  return head == fatihahFirst || bare(head) == bare(fatihahFirst)
      ? head.length + 1
      : 0;
}

/// Ayat-ayat [surah] dengan basmalah ayat 1 dipisah: `basmalah` null bila
/// tidak ada, `verses` berisi ayat tanpa awalan basmalah.
({String? basmalah, List<String> verses}) splitBasmalah(
  int surah,
  List<String> verses,
  String fatihahFirst,
) {
  if (verses.isEmpty) return (basmalah: null, verses: verses);
  final prefix = basmalahPrefix(surah, verses.first, fatihahFirst);
  if (prefix == 0) return (basmalah: null, verses: verses);
  return (
    basmalah: verses.first.substring(0, prefix - 1),
    verses: [verses.first.substring(prefix), ...verses.skip(1)],
  );
}
