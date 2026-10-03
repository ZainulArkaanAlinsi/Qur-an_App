import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/app_dock.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

import '../support/fake_now_playing_audio.dart';
import 'golden_harness.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

/// Latar uji bergaris warna (LIQUID_GLASS.md §8.4): hero hijau, emas,
/// merah, biru, teal, dan teks, supaya efek kaca terlihat di golden.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    Widget band(Color color, double height) =>
        Container(height: height, color: color);
    return ColoredBox(
      color: tokens.bg,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 110,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.heroA,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Langkah berikutnya',
                style: SacredText.headline.copyWith(color: tokens.onHero),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: band(const Color(0xFFC9A13B), 46)),
                Expanded(child: band(const Color(0xFFB0533A), 46)),
                Expanded(child: band(const Color(0xFF2F5FE0), 46)),
                Expanded(child: band(const Color(0xFF0B3F48), 46)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Teks isi halaman yang digulir di balik dock tetap terlihat '
              'samar lewat kaca, tanpa scrim padat.',
              style: SacredText.body.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({required this.audio, this.index = 0});

  final FakeNowPlayingAudio audio;
  final int index;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: _Backdrop()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AppDock(
            tabs: _tabs,
            currentIndex: index,
            onSelected: (_) {},
            audio: audio,
          ),
        ),
      ],
    ),
  );
}

/// Lima dock diam berurutan, satu per tab aktif.
class _AllTabs extends StatelessWidget {
  const _AllTabs();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: _Backdrop()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Column(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppDock(
                        tabs: _tabs,
                        currentIndex: i,
                        onSelected: (_) {},
                        audio: FakeNowPlayingAudio(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Antrean seluruh Al-Fatihah (7 segmen), ayat 5, seperti acuan V6.
FakeNowPlayingAudio _fatihah() => FakeNowPlayingAudio()..play(1, 5, from: 1);

void main() {
  testWidgets('21 dock · diam, kelima tab aktif', (tester) async {
    await pumpGolden(tester, const _AllTabs());
    await expectLater(
      find.byType(_AllTabs),
      matchesGoldenFile('goldens/21_dock_diam_light.png'),
    );
  });

  for (final (name, palette, brightness) in [
    ('light', AppPalette.sacred, Brightness.light),
    ('dark', AppPalette.sacred, Brightness.dark),
    ('sepia', AppPalette.sepia, Brightness.light),
    ('kontras_tinggi', AppPalette.highContrast, Brightness.light),
  ]) {
    testWidgets('21 dock · diputar · $name', (tester) async {
      await pumpGolden(
        tester,
        _Scene(audio: _fatihah()),
        variant: GoldenVariant(brightness, 1),
        palette: palette,
      );
      expect(find.text('Al-Fatihah · Ayat 5'), findsOneWidget);
      await expectLater(
        find.byType(_Scene),
        matchesGoldenFile('goldens/21_dock_diputar_$name.png'),
      );
    });
  }

  testWidgets('21 dock · rentang panjang (bar kontinu)', (tester) async {
    final audio = FakeNowPlayingAudio()..play(2, 12, from: 1, toAyah: 100);
    audio
      ..repeat = AudioRepeat.range
      ..rangePass = 2
      ..rangeTarget = 3
      ..fraction = .5;
    await pumpGolden(tester, _Scene(audio: audio, index: 3));
    expect(find.text('Rentang 1–100 · 2/3'), findsOneWidget);
    await expectLater(
      find.byType(_Scene),
      matchesGoldenFile('goldens/21_dock_rentang_light.png'),
    );
  });

  testWidgets('21 dock · diputar · teks 1.3', (tester) async {
    await pumpGolden(
      tester,
      _Scene(audio: _fatihah()),
      variant: const GoldenVariant(Brightness.light, 1.3),
    );
    expectNotTruncated(tester, [for (final tab in _tabs) tab.label]);
    await expectLater(
      find.byType(_Scene),
      matchesGoldenFile('goldens/21_dock_diputar_light_x1_3.png'),
    );
  });
}
