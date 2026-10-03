import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Kontras teks di atas kaca (docs/design/v4-liquid-glass/LIQUID_GLASS.md §5).
///
/// Model: latar polos adalah kasus terburuk karena blur hanya meratakan warna.
/// Komposit: latar → matriks vibrancy (saturasi + tekan ke `toward`, sama
/// persis dengan yang dipakai `LiquidGlass`) → tint dengan alfanya.

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    .2126 * _channel(c.r) + .7152 * _channel(c.g) + .0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Warna kaca yang terlihat di atas [background] untuk [spec].
Color _glassOver(Color background, GlassSpec spec) {
  final m = glassVibrancyMatrix(
    saturation: spec.saturation,
    keep: spec.keep,
    toward: spec.toward,
  );
  final rgb = [background.r * 255, background.g * 255, background.b * 255];
  double row(int i) =>
      (m[i * 5] * rgb[0] +
              m[i * 5 + 1] * rgb[1] +
              m[i * 5 + 2] * rgb[2] +
              m[i * 5 + 4])
          .clamp(0.0, 255.0) /
      255;
  final backdrop = spec.blur
      ? Color.from(alpha: 1, red: row(0), green: row(1), blue: row(2))
      : background;
  return Color.alphaBlend(spec.tint, backdrop);
}

/// Latar uji §5: putih, hitam, hero, emas, merah, biru, teal, bg terang/gelap.
const _backgrounds = {
  'putih': Color(0xFFFFFFFF),
  'hitam': Color(0xFF000000),
  'hijau hero': Color(0xFF064E3B),
  'emas': Color(0xFFC9A13B),
  'merah': Color(0xFFB0533A),
  'biru': Color(0xFF2F5FE0),
  'teal langit': Color(0xFF0B3F48),
  'bg terang': Color(0xFFF4F1EA),
  'bg gelap': Color(0xFF08110E),
};

final _palettes = {
  'terang': (SacredTokens.light, GlassTokens.light),
  'sepia': (SacredTokens.sepia, GlassTokens.sepia),
  'gelap': (SacredTokens.dark, GlassTokens.dark),
  'kontras tinggi terang': (
    SacredTokens.highContrastLight,
    GlassTokens.highContrastLight,
  ),
  'kontras tinggi gelap': (
    SacredTokens.highContrastDark,
    GlassTokens.highContrastDark,
  ),
};

/// Kontras terendah [text] di atas kaca, di semua latar uji.
double _worst(Color text, GlassSpec spec) => _backgrounds.values
    .map((bg) => _contrast(text, _glassOver(bg, spec)))
    .reduce(math.min);

void main() {
  for (final MapEntry(key: name, value: (sacred, glass)) in _palettes.entries) {
    for (final tier in GlassTier.values) {
      test('teks di kaca $name, tingkat ${tier.name}: ink ≥ 7, sec & '
          'primaryText ≥ 4.5', () {
        for (final size in GlassSize.values) {
          final spec = GlassSpec.resolve(glass, size, tier);
          expect(
            _worst(sacred.ink, spec),
            greaterThanOrEqualTo(7),
            reason: 'ink, $size',
          );
          expect(
            _worst(sacred.sec, spec),
            greaterThanOrEqualTo(4.5),
            reason: 'sec, $size',
          );
          expect(
            _worst(sacred.primaryText, spec),
            greaterThanOrEqualTo(4.5),
            reason: 'primaryText, $size',
          );
        }
      });
    }
  }

  test('alfa tint tidak bisa diturunkan tanpa menggagalkan kontras', () {
    // Penjaga §4: kaca lebih bening 10 poin membuat `sec` < 4.5 di setiap
    // palet kaca. Bila tes ini lulus padahal alfa diturunkan, ambang di atas
    // sudah tidak melindungi apa pun.
    for (final name in ['terang', 'sepia', 'gelap']) {
      final (sacred, glass) = _palettes[name]!;
      final thinner = glass.copyWith(
        tint: glass.tint.withValues(alpha: glass.tint.a - .10),
      );
      final spec = GlassSpec.resolve(thinner, GlassSize.bar, GlassTier.full);
      expect(_worst(sacred.sec, spec), lessThan(4.5), reason: name);
    }
  });

  test('angka tabel §5 tingkat penuh tetap seperti yang dihitung', () {
    double worstOf(String name, Color Function(SacredTokens) text) {
      final (sacred, glass) = _palettes[name]!;
      return _worst(
        text(sacred),
        GlassSpec.resolve(glass, GlassSize.bar, GlassTier.full),
      );
    }

    expect(worstOf('terang', (t) => t.ink), closeTo(12.6, .05));
    expect(worstOf('terang', (t) => t.sec), closeTo(4.57, .02));
    expect(worstOf('terang', (t) => t.primaryText), closeTo(6.92, .02));
    expect(worstOf('sepia', (t) => t.ink), closeTo(8.94, .05));
    expect(worstOf('sepia', (t) => t.sec), closeTo(4.54, .02));
    expect(worstOf('sepia', (t) => t.primaryText), closeTo(6.72, .02));
  });

  test('backdrop yang terlihat 10–18% di tingkat penuh (rubrik G2)', () {
    for (final name in ['terang', 'sepia', 'gelap']) {
      final (_, glass) = _palettes[name]!;
      final visible = (1 - glass.tint.a) * glass.keep;
      expect(visible, inInclusiveRange(.10, .18), reason: name);
    }
  });

  test('kontras tinggi selalu padat, apa pun tingkat yang diminta', () {
    for (final glass in [
      GlassTokens.highContrastLight,
      GlassTokens.highContrastDark,
    ]) {
      for (final tier in GlassTier.values) {
        final spec = GlassSpec.resolve(glass, GlassSize.bar, tier);
        expect(spec.blur, isFalse);
        expect(spec.tint.a, 1);
      }
    }
  });

  test(
    'ringan: sigma 10 (tombol kecil 8), tint +10 poin; padat: tanpa blur',
    () {
      const glass = GlassTokens.light;
      final lite = GlassSpec.resolve(glass, GlassSize.bar, GlassTier.lite);
      final liteSmall = GlassSpec.resolve(
        glass,
        GlassSize.small,
        GlassTier.lite,
      );
      final solid = GlassSpec.resolve(glass, GlassSize.bar, GlassTier.solid);
      expect(lite.sigma, 10);
      expect(liteSmall.sigma, 8);
      expect(lite.tint.a, closeTo(glass.tint.a + .10, 1e-9));
      expect(solid.blur, isFalse);
      expect(solid.tint.a, 1);
    },
  );
}
