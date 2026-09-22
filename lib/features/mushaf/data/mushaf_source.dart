import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

/// Edisi layout mushaf. Keduanya memakai data kata dan glyph `code_v2` yang
/// sama (Mushaf Madinah, QCF); hanya font halamannya berbeda, sehingga
/// pengguna memilih edisi, bukan font bebas.
enum MushafEdition {
  standard('Mushaf Biasa', 'QCF V2', 'v2/ttf'),
  tajweed('Mushaf Tajwid', 'QCF V4 (COLRv1)', 'v4/colrv1/ttf');

  const MushafEdition(this.label, this.technicalName, this.fontPath);

  final String label;
  final String technicalName;
  final String fontPath;

  String fontFamily(int page) => 'qcf_${name}_p$page';

  /// Font halaman diambil dari CDN Quran Foundation. Ketentuan provider
  /// mengizinkan cache/bundel font bila akun Developer Console aktif dan
  /// kredit Quran Foundation ditampilkan.
  Uri fontUri(int page) => Uri.parse(
    'https://verses.quran.foundation/fonts/quran/hafs/$fontPath/p$page.ttf',
  );
}

/// Sumber data mushaf dan tajwid. Implementasinya bisa BFF (produksi) atau
/// pemanggilan langsung api.quran.com (khusus debug).
abstract interface class MushafSource {
  Future<MushafPage> page(int number);

  /// Nama surah berbahasa Arab untuk bingkai judul.
  Future<Map<int, String>> surahNames();

  /// Memuat font halaman dan mengembalikan nama family-nya.
  Future<String> ensureFont(MushafEdition edition, int page);

  /// Markup `text_uthmani_tajweed` per `verseKey` untuk satu surah.
  Future<Map<String, String>> tajweedMarkup(int surah);

  /// Teks polos edisi cadangan per `verseKey` untuk satu surah.
  Future<Map<String, String>> uthmani(int surah);

  void dispose();
}
