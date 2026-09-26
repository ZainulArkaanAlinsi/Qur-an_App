import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Tes kontras kaca (LIQUID_GLASS.md §5 dan §8.2).
///
/// Model: latar polos (kasus terburuk; blur hanya meratakan warna) →
/// vibrancy (matriks yang sama dengan `LiquidGlass`) → tint alfa. Teks
/// label kaca diukur terhadap hasil komposit itu.

/// Luminans relatif WCAG 2.x dari sRGB.
double _luminance(Color c) {
  double lin(double v) =>
      v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * lin(c.r) + .7152 * lin(c.g) + .0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Menerapkan matriks 4x5 `ColorFilter.matrix` (translasi 0..255).
Color _applyMatrix(List<double> m, Color c) {
  final input = [c.r * 255, c.g * 255, c.b * 255, c.a * 255];
  double row(int i) {
    var v = m[i * 5 + 4];
    for (var j = 0; j < 4; j++) {
      v += m[i * 5 + j] * input[j];
    }
    return (v / 255).clamp(0.0, 1.0);
  }

  return Color.from(alpha: row(3), red: row(0), green: row(1), blue: row(2));
}

/// Tint di atas backdrop yang sudah melewati vibrancy.
Color _composite(Color backdrop, GlassSpec spec) {
  final vib = _applyMatrix(
    glassVibrancyMatrix(
      saturation: spec.saturation,
      keep: spec.keep,
      toward: spec.toward,
    ),
    backdrop,
  );
  final a = spec.tint.a;
  double mix(double t, double b) => a * t + (1 - a) * b;
  return Color.from(
    alpha: 1,
    red: mix(spec.tint.r, vib.r),
    green: mix(spec.tint.g, vib.g),
    blue: mix(spec.tint.b, vib.b),
  );
}

/// Latar uji §5: putih, hitam, hijau hero, emas, merah, biru, teal langit,
/// `bg` terang, `bg` gelap.
const _backdrops = <String, Color>{
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

typedef _Case = ({String name, AppPalette palette, Brightness brightness});

const _cases = <_Case>[
  (
    name: 'hijau terang',
    palette: AppPalette.sacred,
    brightness: Brightness.light,
  ),
  (
    name: 'hijau gelap',
    palette: AppPalette.sacred,
    brightness: Brightness.dark,
  ),
  (name: 'sepia', palette: AppPalette.sepia, brightness: Brightness.light),
  (name: 'sepia gelap', palette: AppPalette.sepia, brightness: Brightness.dark),
  (
    name: 'kontras tinggi terang',
    palette: AppPalette.highContrast,
    brightness: Brightness.light,
  ),
  (
    name: 'kontras tinggi gelap',
    palette: AppPalette.highContrast,
    brightness: Brightness.dark,
  ),
];

/// Kontras terburuk ink/sec/primaryText di atas kaca untuk satu palet.
({double ink, double sec, double primaryText}) _worst(
  SacredTokens tokens,
  GlassSpec spec,
) {
  var ink = double.infinity, sec = double.infinity, pt = double.infinity;
  for (final backdrop in _backdrops.values) {
    final surface = _composite(backdrop, spec);
    ink = math.min(ink, _contrast(tokens.ink, surface));
    sec = math.min(sec, _contrast(tokens.sec, surface));
    pt = math.min(pt, _contrast(tokens.primaryText, surface));
  }
  return (ink: ink, sec: sec, primaryText: pt);
}

void main() {
  group('kontras kaca: teks di atas kaca, kasus terburuk §5', () {
    for (final c in _cases) {
      final tokens = SacredTheme.tokensFor(c.palette, c.brightness);
      final glass = SacredTheme.glassFor(c.palette, c.brightness);
      for (final tier in GlassTier.values) {
        for (final size in GlassSize.values) {
          test('${c.name} · ${tier.name} · ${size.name}', () {
            final spec = glass.spec(size, tier);
            for (final MapEntry(key: label, value: backdrop)
                in _backdrops.entries) {
              final surface = _composite(backdrop, spec);
              final where = '${c.name}/${tier.name} di atas $label';
              expect(
                _contrast(tokens.ink, surface),
                greaterThanOrEqualTo(7),
                reason: 'ink $where',
              );
              expect(
                _contrast(tokens.sec, surface),
                greaterThanOrEqualTo(4.5),
                reason: 'sec $where',
              );
              expect(
                _contrast(tokens.primaryText, surface),
                greaterThanOrEqualTo(4.5),
                reason: 'primaryText $where',
              );
            }
          });
        }
      }
    }
  });

  group('kontras kaca: angka tingkat penuh dikunci', () {
    // Nilai terburuk dari model latar polos. Kalau token berubah, perbarui
    // angka ini bersama alasan di LIQUID_GLASS.md / glass_tokens.dart.
    const expected = {
      'hijau terang': (ink: 12.62, sec: 4.57, primaryText: 6.92),
      'sepia': (ink: 8.94, sec: 4.55, primaryText: 6.72),
      'hijau gelap': (ink: 10.28, sec: 4.80, primaryText: 7.65),
    };
    for (final c in _cases) {
      final want = expected[c.name];
      if (want == null) continue;
      test(c.name, () {
        final tokens = SacredTheme.tokensFor(c.palette, c.brightness);
        final glass = SacredTheme.glassFor(c.palette, c.brightness);
        final got = _worst(tokens, glass.spec(GlassSize.bar, GlassTier.full));
        expect(got.ink, closeTo(want.ink, .02));
        expect(got.sec, closeTo(want.sec, .02));
        expect(got.primaryText, closeTo(want.primaryText, .02));
      });
    }
  });

  group('kontras kaca: tint', () {
    test('alfa tint tingkat penuh tidak di bawah angka §4', () {
      // Sepia 48%, bukan 42%: lihat catatan di glass_tokens.dart.
      expect(GlassTokens.light.tint.a, greaterThanOrEqualTo(.38));
      expect(GlassTokens.sepia.tint.a, greaterThanOrEqualTo(.48));
      expect(GlassTokens.dark.tint.a, greaterThanOrEqualTo(.42));
      expect(GlassTokens.highContrastLight.tint.a, 1);
      expect(GlassTokens.highContrastDark.tint.a, 1);
    });

    test('alfa tint palet biasa tetap <= 60% supaya tetap kaca', () {
      for (final glass in [
        GlassTokens.light,
        GlassTokens.sepia,
        GlassTokens.dark,
      ]) {
        expect(glass.tint.a, lessThanOrEqualTo(.60));
        expect(
          glass.spec(GlassSize.bar, GlassTier.lite).tint.a,
          lessThanOrEqualTo(.60),
        );
      }
    });

    test('ringan menambah 10 poin, padat 100%', () {
      for (final glass in [
        GlassTokens.light,
        GlassTokens.sepia,
        GlassTokens.dark,
      ]) {
        final full = glass.spec(GlassSize.bar, GlassTier.full).tint.a;
        final lite = glass.spec(GlassSize.bar, GlassTier.lite).tint.a;
        final solid = glass.spec(GlassSize.bar, GlassTier.solid).tint.a;
        expect(lite, closeTo(full + .10, 1e-9));
        expect(solid, 1);
      }
    });

    test('warna tint sama dengan surf paletnya', () {
      for (final c in _cases) {
        final tokens = SacredTheme.tokensFor(c.palette, c.brightness);
        final glass = SacredTheme.glassFor(c.palette, c.brightness);
        expect(
          glass.tint.withValues(alpha: 1),
          tokens.surf.withValues(alpha: 1),
          reason: c.name,
        );
      }
    });

    test('sigma §4: penuh 18/12/22, ringan 10/8/10, padat 0', () {
      const glass = GlassTokens.light;
      expect(glass.spec(GlassSize.bar, GlassTier.full).sigma, 18);
      expect(glass.spec(GlassSize.small, GlassTier.full).sigma, 12);
      expect(glass.spec(GlassSize.sheet, GlassTier.full).sigma, 22);
      expect(glass.spec(GlassSize.bar, GlassTier.lite).sigma, 10);
      expect(glass.spec(GlassSize.small, GlassTier.lite).sigma, 8);
      expect(glass.spec(GlassSize.sheet, GlassTier.lite).sigma, 10);
      for (final size in GlassSize.values) {
        expect(glass.spec(size, GlassTier.solid).sigma, 0);
        expect(
          GlassTokens.highContrastLight.spec(size, GlassTier.full).sigma,
          0,
        );
      }
    });
  });

  group('matriks vibrancy', () {
    test('saturasi 1 dan keep 1 adalah identitas', () {
      final m = glassVibrancyMatrix(
        saturation: 1,
        keep: 1,
        toward: const Color(0xFF000000),
      );
      const color = Color(0xFF2F5FE0);
      final out = _applyMatrix(m, color);
      expect(out.r, closeTo(color.r, 1e-9));
      expect(out.g, closeTo(color.g, 1e-9));
      expect(out.b, closeTo(color.b, 1e-9));
    });

    test('abu tetap abu setelah saturasi, lalu ditekan ke toward', () {
      final m = glassVibrancyMatrix(
        saturation: 1.7,
        keep: .2,
        toward: const Color(0xFFFFFFFF),
      );
      final out = _applyMatrix(m, const Color(0xFF000000));
      // 20% hitam + 80% putih.
      expect(out.r, closeTo(.8, 1e-9));
      expect(out.g, closeTo(.8, 1e-9));
      expect(out.b, closeTo(.8, 1e-9));
    });
  });
}
