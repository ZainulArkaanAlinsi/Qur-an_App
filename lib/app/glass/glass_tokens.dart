import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';

/// Ukuran kaca. Menentukan sigma blur (LIQUID_GLASS.md §4).
enum GlassSize {
  /// Tab bar, nav pembaca, mini player.
  bar,

  /// Tombol bulat mengambang 40–44.
  small,

  /// Kepala bottom sheet.
  sheet,
}

/// Angka akhir satu kaca setelah ukuran dan tingkat diterapkan. Dipakai
/// untuk membuat filter backdrop dan oleh tes kontras.
@immutable
class GlassSpec {
  const GlassSpec({
    required this.sigma,
    required this.saturation,
    required this.keep,
    required this.toward,
    required this.tint,
  });

  final double sigma;
  final double saturation;
  final double keep;
  final Color toward;

  /// Warna L2 dengan alfa yang sudah disesuaikan tingkat.
  final Color tint;

  @override
  bool operator ==(Object other) =>
      other is GlassSpec &&
      other.sigma == sigma &&
      other.saturation == saturation &&
      other.keep == keep &&
      other.toward == toward &&
      other.tint == tint;

  @override
  int get hashCode => Object.hash(sigma, saturation, keep, toward, tint);
}

/// Token kaca v4 (LIQUID_GLASS.md §4). Dipasang di samping [SacredTokens]
/// oleh `SacredTheme.themeFor`, sehingga ikut palet dan terang/gelap.
///
/// Angka tingkat penuh diambil dari tabel §4, kecuali alfa tint sepia: 48%,
/// bukan 42%. Dengan token sepia yang sebenarnya (`surf` #FBF4E4, `sec`
/// #6E5D44), tint 42% memberi `sec` 4.41 : 1 di atas latar hitam, di bawah
/// ambang 4.5 di §5. Tint 48% memberi 8.94 / 4.55 / 6.72 (ink / sec /
/// primaryText), sama dengan angka sepia di tabel §5. Dikunci oleh
/// `test/glass_contrast_test.dart`.
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

  /// Sigma blur tab bar, nav pembaca, dan mini player.
  final double sigmaBar;

  /// Sigma blur tombol bulat mengambang.
  final double sigmaSmall;

  /// Sigma blur kepala sheet.
  final double sigmaSheet;

  /// Saturasi backdrop sebelum ditekan (L1).
  final double saturation;

  /// Bagian backdrop asli yang tersisa setelah ditekan ke [toward].
  final double keep;

  /// Warna tujuan penekanan: terang di tema terang, gelap di tema gelap.
  final Color toward;

  /// Warna L2: `surf` palet dengan alfa tingkat penuh.
  final Color tint;

  /// Tepi L4: terang di kiri-atas, redup di kanan-bawah.
  final Color rimStart;
  final Color rimEnd;
  final double rimWidth;

  /// Kilau L3 di tepi atas, memudar ke transparan di 55% tinggi.
  final Color sheenTop;

  /// Sorot dalam L5 di tepi atas bagian dalam.
  final Color innerHighlight;

  /// Sigma blur tingkat ringan (§4): 10, tombol kecil 8.
  static const liteSigma = 10.0;
  static const liteSigmaSmall = 8.0;

  /// Tingkat ringan menambah alfa tint 10 poin.
  static const liteTintBoost = .10;

  /// Palet kontras tinggi tidak punya blur sama sekali; kacanya selalu padat.
  bool get solidOnly => sigmaBar == 0;

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
    tint: Color(0x7BFBF4E4),
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
    tint: Color(0x6C111C18),
    rimStart: Color(0x3DFFFFFF),
    rimEnd: Color(0x0DFFFFFF),
    rimWidth: 1,
    sheenTop: Color(0x12FFFFFF),
    innerHighlight: Color(0x2EFFFFFF),
  );

  /// Kontras tinggi: `surf` 100%, tepi `outline` 1.5 px, tanpa kilau.
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

  /// Token dari tema terdekat. Tema tanpa token kaca (mis. tema buatan tes)
  /// memakai token bawaan sesuai kecerahannya.
  static GlassTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GlassTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Angka akhir untuk [size] di [tier] (§4, tabel tingkat kualitas).
  GlassSpec spec(GlassSize size, GlassTier tier) {
    final fullSigma = switch (size) {
      GlassSize.bar => sigmaBar,
      GlassSize.small => sigmaSmall,
      GlassSize.sheet => sigmaSheet,
    };
    final sigma = switch (tier) {
      GlassTier.full => fullSigma,
      GlassTier.lite =>
        solidOnly
            ? 0.0
            : size == GlassSize.small
            ? liteSigmaSmall
            : liteSigma,
      GlassTier.solid => 0.0,
    };
    final alpha = switch (tier) {
      GlassTier.full => tint.a,
      GlassTier.lite => (tint.a + liteTintBoost).clamp(0.0, 1.0),
      GlassTier.solid => 1.0,
    };
    return GlassSpec(
      sigma: sigma,
      saturation: saturation,
      keep: keep,
      toward: toward,
      tint: tint.withValues(alpha: alpha),
    );
  }

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
    double mixD(double a, double b) => lerpDouble(a, b, t) ?? a;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return GlassTokens(
      sigmaBar: mixD(sigmaBar, other.sigmaBar),
      sigmaSmall: mixD(sigmaSmall, other.sigmaSmall),
      sigmaSheet: mixD(sigmaSheet, other.sigmaSheet),
      saturation: mixD(saturation, other.saturation),
      keep: mixD(keep, other.keep),
      toward: mix(toward, other.toward),
      tint: mix(tint, other.tint),
      rimStart: mix(rimStart, other.rimStart),
      rimEnd: mix(rimEnd, other.rimEnd),
      rimWidth: mixD(rimWidth, other.rimWidth),
      sheenTop: mix(sheenTop, other.sheenTop),
      innerHighlight: mix(innerHighlight, other.innerHighlight),
    );
  }
}
