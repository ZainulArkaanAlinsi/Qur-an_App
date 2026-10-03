import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';

/// Token kaca per palet (docs/design/v4-liquid-glass/LIQUID_GLASS.md §4).
///
/// Angka di sini sudah dihitung terhadap ambang kontras §5 dan dikunci oleh
/// `test/glass_contrast_test.dart`; jangan diubah tanpa menjalankan tes itu.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.sigmaBar,
    required this.sigmaSmall,
    required this.sigmaSheet,
    required this.saturation,
    required this.keep,
    required this.toward,
    required this.tint,
    required this.rimStart,
    required this.rimEnd,
    required this.rimWidth,
    required this.sheenTop,
    required this.innerHighlight,
  });

  /// Blur tab bar / nav / mini player.
  final double sigmaBar;

  /// Blur tombol bulat mengambang (40–44).
  final double sigmaSmall;

  /// Blur kepala bottom sheet.
  final double sigmaSheet;

  /// Saturasi backdrop sebelum ditekan (vibrancy, §3).
  final double saturation;

  /// Bagian backdrop asli yang tersisa setelah ditekan ke [toward].
  final double keep;

  /// Warna tujuan penekanan: terang untuk tema terang, gelap untuk gelap.
  final Color toward;

  /// L2: `surf` dengan alfa per palet.
  final Color tint;

  /// L4: tepi bergradien dari kiri-atas ke kanan-bawah.
  final Color rimStart;
  final Color rimEnd;
  final double rimWidth;

  /// L3: kilau atas, memudar ke transparan di 55% tinggi.
  final Color sheenTop;

  /// L5: sorot 1 px di tepi atas bagian dalam.
  final Color innerHighlight;

  /// Palet kontras tinggi selalu padat (§4, tabel tingkat kualitas).
  bool get forcesSolid => sigmaBar == 0;

  static const light = GlassTokens(
    sigmaBar: 18,
    sigmaSmall: 12,
    sigmaSheet: 22,
    saturation: 1.7,
    keep: .20,
    toward: Color(0xFFFFFFFF),
    tint: Color(0x61FCF9F8),
    rimStart: Color(0xB3FFFFFF),
    rimEnd: Color(0x26FFFFFF),
    rimWidth: 1,
    sheenTop: Color(0x2EFFFFFF),
    innerHighlight: Color(0x80FFFFFF),
  );

  static const sepia = GlassTokens(
    sigmaBar: 18,
    sigmaSmall: 12,
    sigmaSheet: 22,
    saturation: 1.5,
    keep: .20,
    toward: Color(0xFFF9F2E2),
    // 48%, bukan 42% seperti tabel §4: dengan 42% `sec` di latar hitam
    // hanya 4.41 (< 4.5). Hasil 48% (ink 8.93, sec 4.54, primaryText 6.71)
    // sama dengan baris sepia tabel §5, jadi tabel §5 memang dihitung
    // dengan 48%. Dikunci test/glass_contrast_test.dart.
    tint: Color(0x7AFBF4E4),
    rimStart: Color(0x99FFFFFF),
    rimEnd: Color(0x1FFFFFFF),
    rimWidth: 1,
    sheenTop: Color(0x24FFFFFF),
    innerHighlight: Color(0x66FFFFFF),
  );

  static const dark = GlassTokens(
    sigmaBar: 18,
    sigmaSmall: 12,
    sigmaSheet: 22,
    saturation: 1.7,
    keep: .30,
    toward: Color(0xFF000000),
    tint: Color(0x6B111C18),
    rimStart: Color(0x3DFFFFFF),
    rimEnd: Color(0x0DFFFFFF),
    rimWidth: 1,
    sheenTop: Color(0x12FFFFFF),
    innerHighlight: Color(0x2EFFFFFF),
  );

  /// Padat: tanpa blur, tint `surf` penuh, tepi `outline` 1.5 px.
  static const highContrastLight = GlassTokens(
    sigmaBar: 0,
    sigmaSmall: 0,
    sigmaSheet: 0,
    saturation: 1,
    keep: 1,
    toward: Color(0xFFFFFFFF),
    tint: Color(0xFFFFFFFF),
    rimStart: Color(0xFF3A3A3A),
    rimEnd: Color(0xFF3A3A3A),
    rimWidth: 1.5,
    sheenTop: Color(0x00FFFFFF),
    innerHighlight: Color(0x00FFFFFF),
  );

  static const highContrastDark = GlassTokens(
    sigmaBar: 0,
    sigmaSmall: 0,
    sigmaSheet: 0,
    saturation: 1,
    keep: 1,
    toward: Color(0xFF000000),
    tint: Color(0xFF0A0A0A),
    rimStart: Color(0xFF9A9A9A),
    rimEnd: Color(0xFF9A9A9A),
    rimWidth: 1.5,
    sheenTop: Color(0x00FFFFFF),
    innerHighlight: Color(0x00FFFFFF),
  );

  @override
  GlassTokens copyWith({
    double? sigmaBar,
    double? sigmaSmall,
    double? sigmaSheet,
    double? saturation,
    double? keep,
    Color? toward,
    Color? tint,
    Color? rimStart,
    Color? rimEnd,
    double? rimWidth,
    Color? sheenTop,
    Color? innerHighlight,
  }) => GlassTokens(
    sigmaBar: sigmaBar ?? this.sigmaBar,
    sigmaSmall: sigmaSmall ?? this.sigmaSmall,
    sigmaSheet: sigmaSheet ?? this.sigmaSheet,
    saturation: saturation ?? this.saturation,
    keep: keep ?? this.keep,
    toward: toward ?? this.toward,
    tint: tint ?? this.tint,
    rimStart: rimStart ?? this.rimStart,
    rimEnd: rimEnd ?? this.rimEnd,
    rimWidth: rimWidth ?? this.rimWidth,
    sheenTop: sheenTop ?? this.sheenTop,
    innerHighlight: innerHighlight ?? this.innerHighlight,
  );

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    double num(double a, double b) => lerpDouble(a, b, t) ?? a;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return GlassTokens(
      sigmaBar: num(sigmaBar, other.sigmaBar),
      sigmaSmall: num(sigmaSmall, other.sigmaSmall),
      sigmaSheet: num(sigmaSheet, other.sigmaSheet),
      saturation: num(saturation, other.saturation),
      keep: num(keep, other.keep),
      toward: mix(toward, other.toward),
      tint: mix(tint, other.tint),
      rimStart: mix(rimStart, other.rimStart),
      rimEnd: mix(rimEnd, other.rimEnd),
      rimWidth: num(rimWidth, other.rimWidth),
      sheenTop: mix(sheenTop, other.sheenTop),
      innerHighlight: mix(innerHighlight, other.innerHighlight),
    );
  }
}

/// Ukuran kaca; menentukan sigma (§4).
enum GlassSize { bar, small, sheet }

/// Angka satu permukaan kaca setelah token, ukuran, dan tingkat digabung.
///
/// Dipakai `LiquidGlass` untuk menggambar dan oleh tes kontras untuk
/// menghitung, supaya keduanya tidak bisa berbeda.
@immutable
class GlassSpec {
  const GlassSpec({
    required this.sigma,
    required this.saturation,
    required this.keep,
    required this.toward,
    required this.tint,
    required this.blur,
  });

  /// Tingkat ringan: sigma 10 (tombol kecil 8) dan alfa tint +10 poin;
  /// padat: tanpa blur dan tint penuh (§4). Bentuk tidak berubah.
  factory GlassSpec.resolve(
    GlassTokens tokens,
    GlassSize size,
    GlassTier tier,
  ) {
    final effective = tokens.forcesSolid ? GlassTier.solid : tier;
    final full = switch (size) {
      GlassSize.bar => tokens.sigmaBar,
      GlassSize.small => tokens.sigmaSmall,
      GlassSize.sheet => tokens.sigmaSheet,
    };
    return switch (effective) {
      GlassTier.full => GlassSpec(
        sigma: full,
        saturation: tokens.saturation,
        keep: tokens.keep,
        toward: tokens.toward,
        tint: tokens.tint,
        blur: true,
      ),
      GlassTier.lite => GlassSpec(
        sigma: size == GlassSize.small ? 8 : 10,
        saturation: tokens.saturation,
        keep: tokens.keep,
        toward: tokens.toward,
        tint: tokens.tint.withValues(
          alpha: (tokens.tint.a + .10).clamp(0.0, 1.0),
        ),
        blur: true,
      ),
      GlassTier.solid => GlassSpec(
        sigma: 0,
        saturation: 1,
        keep: 1,
        toward: tokens.toward,
        tint: tokens.tint.withValues(alpha: 1),
        blur: false,
      ),
    };
  }

  final double sigma;
  final double saturation;
  final double keep;
  final Color toward;
  final Color tint;

  /// `false` = `BackdropFilter.grouped(enabled: false)`: pohon layer tetap.
  final bool blur;
}

/// Matriks 4x5 untuk `ColorFilter.matrix` (LIQUID_GLASS.md §3): saturasi
/// `s`, lalu rentang terang ditekan ke [toward] dengan menyisakan `keep`
/// bagian backdrop asli. Kolom translasi dalam skala 0..255.
List<double> glassVibrancyMatrix({
  required double saturation,
  required double keep,
  required Color toward,
}) {
  const lr = .2126, lg = .7152, lb = .0722; // bobot luminans Rec.709
  final s = saturation;
  final sat = [
    [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
  ];
  final t = [toward.r * 255, toward.g * 255, toward.b * 255];
  return [
    for (var i = 0; i < 3; i++) ...[
      for (var j = 0; j < 3; j++) keep * sat[i][j],
      0,
      (1 - keep) * t[i],
    ],
    0,
    0,
    0,
    1,
    0,
  ];
}

/// L1: vibrancy di atas blur, dalam satu filter.
ui.ImageFilter glassFilter(GlassSpec spec) => ui.ImageFilter.compose(
  outer: ui.ColorFilter.matrix(
    glassVibrancyMatrix(
      saturation: spec.saturation,
      keep: spec.keep,
      toward: spec.toward,
    ),
  ),
  inner: ui.ImageFilter.blur(
    sigmaX: spec.sigma,
    sigmaY: spec.sigma,
    tileMode: TileMode.mirror,
  ),
);
