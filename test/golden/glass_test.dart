import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_circle_button.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';

import 'golden_harness.dart';

/// Golden kaca v4 (LIQUID_GLASS.md §8.4): tab bar, bilah nav, mini player,
/// kepala sheet, dan tombol bulat × {terang, gelap, sepia, kontras tinggi} ×
/// {penuh, padat}, di atas latar uji bergaris warna supaya efek kaca terlihat.
/// Bayangan dirender sungguhan.
const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

/// Latar uji §5: putih, hitam, hijau hero, emas, merah, biru, teal langit.
const _stripes = [
  Color(0xFFFFFFFF),
  Color(0xFF000000),
  Color(0xFF064E3B),
  Color(0xFFC9A13B),
  Color(0xFFB0533A),
  Color(0xFF2F5FE0),
  Color(0xFF0B3F48),
];

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final color in _stripes)
            Expanded(child: ColoredBox(color: color)),
        ],
      ),
      // Teks di belakang kaca: harus tampak samar, tidak terbaca tajam.
      Column(
        children: [
          for (var i = 0; i < 26; i++)
            Expanded(
              child: Center(
                child: Text(
                  'Isi halaman di balik kaca · $i',
                  style: TextStyle(
                    fontFamily: SacredText.ui,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: i.isEven
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF000000),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _Scene extends StatelessWidget {
  const _Scene();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: BackdropGroup(
        child: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            // Bilah nav pembaca: kaca selebar layar yang menempel di atas.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LiquidGlass(
                borderRadius: BorderRadius.zero,
                shadow: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
                  child: Row(
                    children: [
                      Text(
                        'Surah',
                        style: SacredText.backLabel.copyWith(
                          color: tokens.primaryText,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Al-Fatihah',
                              style: SacredText.navTitle.copyWith(
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              'Kartu ayat · 7 ayat',
                              style: SacredText.navSubtitle.copyWith(
                                color: tokens.sec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            // Kartu hero hijau dengan tombol bulat kaca.
            Positioned(
              top: 250,
              left: 16,
              right: 16,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.art,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Align(
                  alignment: const Alignment(.85, 0),
                  child: GlassCircleButton(
                    icon: SacredIcons.headphones,
                    tooltip: 'Dengarkan murottal',
                    onTap: () {},
                  ),
                ),
              ),
            ),
            // Kepala sheet kaca di atas garis warna.
            Positioned(
              top: 420,
              left: 0,
              right: 0,
              height: 150,
              child: GlassSheet(
                background: tokens.surf,
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tampilan baca',
                          style: SacredText.headline.copyWith(
                            color: tokens.ink,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Text(
                        'Selesai',
                        style: SacredText.headline.copyWith(
                          color: tokens.primaryText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AudioMiniPlayer(),
                  ),
                  FloatingTabBar(
                    tabs: _tabs,
                    currentIndex: 1,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Look = ({String name, AppPalette palette, Brightness brightness});

const _looks = <_Look>[
  (name: 'terang', palette: AppPalette.sacred, brightness: Brightness.light),
  (name: 'gelap', palette: AppPalette.sacred, brightness: Brightness.dark),
  (name: 'sepia', palette: AppPalette.sepia, brightness: Brightness.light),
  (
    name: 'kontras_tinggi',
    palette: AppPalette.highContrast,
    brightness: Brightness.light,
  ),
];

void main() {
  for (final look in _looks) {
    for (final solid in [false, true]) {
      final tier = solid ? 'padat' : 'penuh';
      testWidgets('kaca · ${look.name} · $tier', (tester) async {
        final audio = QuranAudioService.instance;
        addTearDown(() {
          audio.queue.value = null;
          audio.playingVerse.value = null;
        });
        final glass = GlassController();
        if (solid) await glass.setPreference(GlassPreference.off);

        tester.view.physicalSize = phone * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(
          top: statusBar * 3,
          bottom: gestureBar * 3,
        );
        tester.view.viewPadding = const FakeViewPadding(
          top: statusBar * 3,
          bottom: gestureBar * 3,
        );
        addTearDown(tester.view.reset);
        debugDisableShadows = false;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SacredTheme.themeFor(look.palette, look.brightness),
            builder: (context, child) =>
                GlassScope(controller: glass, child: child!),
            home: const _Scene(),
          ),
        );
        await tester.pumpAndSettle();
        // Diisi setelah layar terpasang: aliran pemutar yang baru dibuat bisa
        // mengosongkan nilai yang diisi lebih awal.
        audio.queue.value = AudioQueue.from(1, 1);
        audio.playingVerse.value = '1:2';
        await tester.pumpAndSettle();
        expect(find.byType(AudioMiniPlayer), findsOneWidget);
        expect(find.text('Al-Fatihah · Ayat 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/glass/kaca_${look.name}_$tier.png'),
        );
        debugDisableShadows = true;
      });
    }
  }
}
