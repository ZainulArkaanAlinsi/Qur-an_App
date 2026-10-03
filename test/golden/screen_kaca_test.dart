import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/app_dock.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

import '../support/fake_now_playing_audio.dart';
import 'golden_harness.dart';

/// Golden kaca (v4 Prompt 3 §4, LIQUID_GLASS.md): dock (tab + sedang
/// diputar), kepala sheet, dan tombol bulat mengambang di atas latar uji
/// (kartu hero hijau, teks, garis warna) × 4 palet × tingkat penuh/padat.
const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

class _Scene extends StatelessWidget {
  const _Scene({required this.audio});

  final FakeNowPlayingAudio audio;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Latar uji: garis warna, kartu hero, dan teks.
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final color in [
                  tokens.heroA,
                  tokens.gold,
                  tokens.primaryText,
                  tokens.goldSoft,
                  tokens.teal,
                  tokens.danger,
                ])
                  Expanded(child: ColoredBox(color: color)),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 300,
            child: Container(
              height: 220,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [tokens.heroA, tokens.heroB]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                'Teks di belakang kaca harus samar, bukan hilang.',
                style: SacredText.heroTitle.copyWith(color: tokens.onHero),
              ),
            ),
          ),
          // Kepala sheet berkaca (isi padat), seperti showGlassSheet.
          Positioned(
            left: 0,
            right: 0,
            top: 100,
            height: 170,
            child: GlassSheet(
              title: 'Waktu salat',
              action: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Simpan',
                  style: SacredText.button.copyWith(color: tokens.primaryText),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Isi lembar padat',
                  style: SacredText.body.copyWith(color: tokens.ink),
                ),
              ),
            ),
          ),
          // Tombol bulat mengambang.
          Positioned(
            right: 24,
            top: 560,
            child: LiquidGlass(
              size: GlassSize.small,
              borderRadius: BorderRadius.circular(28),
              child: SizedBox.square(
                dimension: 56,
                child: Center(
                  child: LineIcon(
                    SacredIcons.play,
                    color: tokens.ink,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppDock(
              tabs: _tabs,
              currentIndex: 1,
              onSelected: (_) {},
              audio: audio,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  final palettes = {
    'light': (AppPalette.sacred, Brightness.light),
    'dark': (AppPalette.sacred, Brightness.dark),
    'sepia': (AppPalette.sepia, Brightness.light),
    'kontras_tinggi': (AppPalette.highContrast, Brightness.light),
  };
  final tiers = {'full': GlassPreference.full, 'solid': GlassPreference.off};
  for (final MapEntry(key: name, value: (palette, brightness))
      in palettes.entries) {
    for (final MapEntry(key: tier, value: preference) in tiers.entries) {
      testWidgets('kaca · $name · $tier', (tester) async {
        final audio = FakeNowPlayingAudio()..play(1, 3, from: 1);
        await pumpGolden(
          tester,
          GlassScope(
            controller: GlassController(preference: preference),
            child: _Scene(audio: audio),
          ),
          variant: GoldenVariant(brightness, 1),
          palette: palette,
        );
        expect(tester.takeException(), isNull);
        // Label tab tidak aktif tetap utuh.
        expectNotTruncated(tester, [for (final tab in _tabs) tab.label]);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/kaca_${name}_$tier.png'),
        );
      });
    }
  }
}
