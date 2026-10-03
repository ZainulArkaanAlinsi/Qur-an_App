import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
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

  test('token kaca ikut di setiap tema; kontras tinggi selalu padat', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final glass = SacredTheme.themeFor(
          palette,
          brightness,
        ).extension<GlassTokens>();
        expect(glass, isNotNull, reason: '$palette $brightness');
        expect(
          glass!.forcesSolid,
          palette == AppPalette.highContrast,
          reason: '$palette $brightness',
        );
      }
    }
  });

  // docs/design/v6/DESIGN.md §3: token v6 dan kontras yang wajib dites.
  // Nilai hasil hitungan di dokumen: onHero/heroB 11.7 · 13.6, onHeroSec/heroA
  // 5.5 · 5.7, goldLine/heroA 4.9 · 4.9, onGoldButton/goldButton 11.5,
  // teal/surf 5.6 · 5.3 (sepia) · 9.8.
  group('token v6 di semua palet', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final name = '$palette $brightness';
        final t = SacredTheme.tokensFor(palette, brightness);

        test('$name: teal di surf ≥ 3 (elemen grafis)', () {
          expect(_contrast(t.teal, t.surf), greaterThanOrEqualTo(3));
        });

        test('$name: teks kartu hijau terbaca', () {
          expect(_contrast(t.onHero, t.heroB), greaterThanOrEqualTo(7));
          // onHeroSec semi-transparan: dihitung setelah dikomposit di heroA.
          expect(
            _contrast(Color.alphaBlend(t.onHeroSec, t.heroA), t.heroA),
            greaterThanOrEqualTo(4.5),
          );
          // Eyebrow 11/800 dihitung teks kecil.
          expect(_contrast(t.goldLine, t.heroA), greaterThanOrEqualTo(4.5));
          expect(
            _contrast(t.onGoldButton, t.goldButton),
            greaterThanOrEqualTo(7),
          );
        });
      }
    }

    test('kontras tinggi: kartu hijau padat dan horizon = surf', () {
      for (final brightness in Brightness.values) {
        final t = SacredTheme.tokensFor(AppPalette.highContrast, brightness);
        expect(t.heroA, t.heroB);
        expect(t.skyHorizon, t.surf);
      }
    });

    test('lerp dan copyWith ikut membawa token v6', () {
      final mid = SacredTokens.light.lerp(SacredTokens.dark, .5);
      expect(
        mid.teal,
        Color.lerp(SacredTokens.light.teal, SacredTokens.dark.teal, .5),
      );
      expect(
        mid.skyHorizon,
        Color.lerp(
          SacredTokens.light.skyHorizon,
          SacredTokens.dark.skyHorizon,
          .5,
        ),
      );
      expect(
        SacredTokens.light.copyWith(goldLine: const Color(0xFF000000)).goldLine,
        const Color(0xFF000000),
      );
    });
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
