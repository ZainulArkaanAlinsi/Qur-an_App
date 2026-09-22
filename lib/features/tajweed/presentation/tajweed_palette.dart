import 'package:flutter/material.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Preset warna tajwid bernama untuk Mode Card.
///
/// Tidak ada skema warna tajwid yang universal. Preset ini dipilih agar setiap
/// warna berkontras >= 4:1 terhadap permukaan kartu terang dan gelap
/// (`test/tajweed_widget_test.dart`), dan statusnya draft sampai direview guru
/// tajwid. Warna tidak pernah menjadi satu-satunya penanda: nama hukum selalu
/// tersedia lewat chip, legend, dan ketukan segmen.
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
      TajweedRule.hamzahWasl: Color(0xFF7A7A7A),
      TajweedRule.lamSyamsiyah: Color(0xFF7A7A7A),
      TajweedRule.silent: Color(0xFF7A7A7A),
      TajweedRule.madThabii: Color(0xFF2F5FE0),
      TajweedRule.madJaiz: Color(0xFF3340D0),
      TajweedRule.madWajib: Color(0xFF0A1596),
      TajweedRule.madLazim: Color(0xFF5A0F8C),
      TajweedRule.qalqalah: Color(0xFFC8000A),
      TajweedRule.ikhfaHaqiqi: Color(0xFF8A009C),
      TajweedRule.ikhfaSyafawi: Color(0xFFB0009A),
      TajweedRule.idghamBighunnah: Color(0xFF127A60),
      TajweedRule.idghamBilaghunnah: Color(0xFF1F7A12),
      TajweedRule.idghamMimi: Color(0xFF3C8A00),
      TajweedRule.idghamMutajanisain: Color(0xFF6E6E6E),
      TajweedRule.idghamMutaqaribain: Color(0xFF6E6E6E),
      TajweedRule.iqlab: Color(0xFF0078B8),
      TajweedRule.ghunnah: Color(0xFFC25400),
    },
    dark: {
      TajweedRule.hamzahWasl: Color(0xFF9A9A9A),
      TajweedRule.lamSyamsiyah: Color(0xFF9A9A9A),
      TajweedRule.silent: Color(0xFF9A9A9A),
      TajweedRule.madThabii: Color(0xFF8FA8FF),
      TajweedRule.madJaiz: Color(0xFFA0A8FF),
      TajweedRule.madWajib: Color(0xFF7F8CFF),
      TajweedRule.madLazim: Color(0xFFC69BFF),
      TajweedRule.qalqalah: Color(0xFFFF7A7A),
      TajweedRule.ikhfaHaqiqi: Color(0xFFD98BFF),
      TajweedRule.ikhfaSyafawi: Color(0xFFFF8AE6),
      TajweedRule.idghamBighunnah: Color(0xFF52D6B0),
      TajweedRule.idghamBilaghunnah: Color(0xFF7DDB6E),
      TajweedRule.idghamMimi: Color(0xFF8FE05A),
      TajweedRule.idghamMutajanisain: Color(0xFFA8A8A8),
      TajweedRule.idghamMutaqaribain: Color(0xFFA8A8A8),
      TajweedRule.iqlab: Color(0xFF5CCBFF),
      TajweedRule.ghunnah: Color(0xFFFFA25C),
    },
  );
}
