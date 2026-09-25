import 'package:flutter/material.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Preset warna tajwid bernama untuk Mode Card.
///
/// Tidak ada skema warna tajwid yang universal. Preset ini dipilih agar setiap
/// warna berkontras >= 4.5:1 terhadap SEMUA permukaan ayat: kartu, latar,
/// ayat aktif, ayat bertanda, sepia, dan kontras tinggi, di terang dan gelap
/// (LIQUID_GLASS.md §5, `test/tajweed_widget_test.dart`). Statusnya draft
/// sampai direview guru tajwid. Warna tidak pernah menjadi satu-satunya
/// penanda: nama hukum selalu tersedia lewat chip, legend, dan ketukan segmen.
///
/// Revisi v4 (25 September 2026): abu, mad thabi'i, tiga idgham, iqlab, dan
/// ghunnah terang digelapkan; mad wajib gelap digeser ke biru langit; idgham
/// mimi digeser ke hijau-kuning di kedua tema supaya tidak kembar dengan
/// idgham bilaghunnah. Hubungan antarwarna dijaga (tabel ΔE2000 di
/// docs/design/v4-liquid-glass/HASIL_AUDIT.md).
class TajweedPalette {
  const TajweedPalette({
    required this.id,
    required this.name,
    required this.reviewStatus,
    required this.light,
    required this.dark,
  });

  final String id;
  final String name;
  final ContentReviewStatus reviewStatus;
  final Map<TajweedRule, Color> light;
  final Map<TajweedRule, Color> dark;

  Color colorFor(TajweedRule rule, Brightness brightness) =>
      (brightness == Brightness.dark ? dark : light)[rule]!;

  static const draftPreview = TajweedPalette(
    id: 'draft-preview-1',
    name: 'Pratinjau',
    reviewStatus: ContentReviewStatus.draft,
    light: {
      TajweedRule.hamzahWasl: Color(0xFF676767),
      TajweedRule.lamSyamsiyah: Color(0xFF676767),
      TajweedRule.silent: Color(0xFF676767),
      TajweedRule.madThabii: Color(0xFF0B5FE0),
      TajweedRule.madJaiz: Color(0xFF3340D0),
      TajweedRule.madWajib: Color(0xFF0A1596),
      TajweedRule.madLazim: Color(0xFF5A0F8C),
      TajweedRule.qalqalah: Color(0xFFC8000A),
      TajweedRule.ikhfaHaqiqi: Color(0xFF8A009C),
      TajweedRule.ikhfaSyafawi: Color(0xFFB0009A),
      TajweedRule.idghamBighunnah: Color(0xFF00765F),
      TajweedRule.idghamBilaghunnah: Color(0xFF1D7810),
      TajweedRule.idghamMimi: Color(0xFF587000),
      TajweedRule.idghamMutajanisain: Color(0xFF565656),
      TajweedRule.idghamMutaqaribain: Color(0xFF565656),
      TajweedRule.iqlab: Color(0xFF017095),
      TajweedRule.ghunnah: Color(0xFFA05300),
    },
    dark: {
      TajweedRule.hamzahWasl: Color(0xFF9A9A9A),
      TajweedRule.lamSyamsiyah: Color(0xFF9A9A9A),
      TajweedRule.silent: Color(0xFF9A9A9A),
      TajweedRule.madThabii: Color(0xFF8FA8FF),
      TajweedRule.madJaiz: Color(0xFFA0A8FF),
      TajweedRule.madWajib: Color(0xFF5A97FD),
      TajweedRule.madLazim: Color(0xFFC69BFF),
      TajweedRule.qalqalah: Color(0xFFFF7A7A),
      TajweedRule.ikhfaHaqiqi: Color(0xFFD98BFF),
      TajweedRule.ikhfaSyafawi: Color(0xFFFF8AE6),
      TajweedRule.idghamBighunnah: Color(0xFF52D6B0),
      TajweedRule.idghamBilaghunnah: Color(0xFF7DDB6E),
      TajweedRule.idghamMimi: Color(0xFFB5D943),
      TajweedRule.idghamMutajanisain: Color(0xFFA8A8A8),
      TajweedRule.idghamMutaqaribain: Color(0xFFA8A8A8),
      TajweedRule.iqlab: Color(0xFF5CCBFF),
      TajweedRule.ghunnah: Color(0xFFFFA25C),
    },
  );
}
