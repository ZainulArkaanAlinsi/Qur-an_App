import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  test('token tersedia di setiap palet dan kecerahan', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final theme = SacredTheme.themeFor(palette, brightness);
        final tokens = theme.extension<SacredTokens>();
        expect(tokens, isNotNull, reason: '$palette $brightness');
        expect(tokens!.heatmap, hasLength(4));
      }
    }
  });

  test('sepia terang memakai token sepia, bukan token hijau', () {
    final tokens = SacredTheme.tokensFor(AppPalette.sepia, Brightness.light);
    expect(tokens.bg, const Color(0xFFF4ECD8));
    expect(tokens.surf, const Color(0xFFFBF4E4));
  });

  test('teks utama dan sekunder memenuhi kontras minimum', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final tokens = SacredTheme.tokensFor(palette, brightness);
        expect(
          _contrast(tokens.ink, tokens.bg),
          greaterThanOrEqualTo(4.5),
          reason: 'ink $palette $brightness',
        );
        expect(
          _contrast(tokens.sec, tokens.surf),
          greaterThanOrEqualTo(4.5),
          reason: 'sec $palette $brightness',
        );
        // Teks di atas tombol utama dan kartu hero.
        expect(
          _contrast(tokens.ctaInk, tokens.cta),
          greaterThanOrEqualTo(4.5),
          reason: 'cta $palette $brightness',
        );
        expect(
          _contrast(tokens.artInk, tokens.art),
          greaterThanOrEqualTo(4.5),
          reason: 'art $palette $brightness',
        );
      }
    }
  });

  test('emas untuk teks memakai goldText di latar terang', () {
    final light = SacredTheme.tokensFor(AppPalette.sacred, Brightness.light);
    expect(_contrast(light.goldText, light.surf), greaterThanOrEqualTo(4.5));
    // Emas ornamen memang tidak untuk teks kecil di latar terang.
    expect(_contrast(light.gold, light.surf), lessThan(4.5));
  });

  test('heatmap menaik dari kosong ke penuh', () {
    for (final brightness in Brightness.values) {
      final tokens = SacredTheme.tokensFor(AppPalette.sacred, brightness);
      final contrasts = [
        for (final level in tokens.heatmap) _contrast(level, tokens.bg),
      ];
      // Tingkat terakhir harus paling menonjol dari latar.
      expect(contrasts.last, greaterThan(contrasts.first));
    }
  });

  group('gradien langit', () {
    test('periode dipilih dari jam setempat', () {
      expect(SkyPeriod.fromHour(5), SkyPeriod.fajr);
      expect(SkyPeriod.fromHour(12), SkyPeriod.day);
      expect(SkyPeriod.fromHour(16), SkyPeriod.dusk);
      expect(SkyPeriod.fromHour(23), SkyPeriod.night);
      expect(SkyPeriod.fromHour(2), SkyPeriod.night);
    });

    test('setiap periode punya gradien vertikal', () {
      for (final period in SkyPeriod.values) {
        expect(period.colors.length, greaterThanOrEqualTo(3));
        expect(period.gradient.begin, Alignment.topCenter);
        expect(period.gradient.end, Alignment.bottomCenter);
      }
    });
  });

  test('gaya teks memakai font yang dibundel dan tinggi baris spesifikasi', () {
    expect(SacredText.largeTitle.fontFamily, 'EBGaramond');
    expect(SacredText.body.fontFamily, 'PlusJakartaSans');
    expect(SacredText.body.fontSize, 15);
    expect(SacredText.body.height, closeTo(23 / 15, 0.001));
    // Ketebalan font variabel diatur lewat fontVariations.
    expect(SacredText.headline.fontVariations, isNotEmpty);
    expect(SacredText.headline.fontVariations!.first.value, 700);
    expect(SacredText.eyebrow.letterSpacing, closeTo(1.32, 0.001));
  });
}
