import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mini player kaca v4: LiquidGlass + token di semua palet, muncul dari
/// bawah (LIQUID_GLASS.md §2, §6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final audio = QuranAudioService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  tearDown(() {
    audio.queue.value = null;
    audio.playingVerse.value = null;
    audio.isPlaying.value = false;
  });

  Future<void> pump(
    WidgetTester tester,
    AppPalette palette,
    Brightness brightness,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(palette, brightness),
      home: const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AudioMiniPlayer(),
        ),
      ),
    ),
  );

  void play() {
    audio.queue.value = AudioQueue.from(112, 1);
    audio.playingVerse.value = '112:2';
  }

  for (final palette in AppPalette.values) {
    for (final brightness in Brightness.values) {
      testWidgets('warna dari token · ${palette.name} ${brightness.name}', (
        tester,
      ) async {
        final tokens = SacredTheme.tokensFor(palette, brightness);
        await pump(tester, palette, brightness);
        play();
        await tester.pumpAndSettle();

        expect(find.byType(LiquidGlass), findsOneWidget);
        final title = tester.widget<Text>(find.text('Al-Ikhlas · Ayat 2'));
        expect(title.style?.color, tokens.ink);
        final subtitle = tester.widget<Text>(
          find.text(QuranAudioService.reciterName),
        );
        expect(subtitle.style?.color, tokens.sec);

        // Tombol putar tetap CTA pekat.
        final playButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.play_arrow_rounded),
            matching: find.byType(IconButton),
          ),
        );
        expect(playButton.style?.backgroundColor?.resolve(const {}), tokens.cta);
        expect(playButton.style?.foregroundColor?.resolve(const {}), tokens.ctaInk);
      });
    }
  }

  testWidgets('muncul dari bawah dalam 280 ms, lalu hilang', (tester) async {
    await pump(tester, AppPalette.sacred, Brightness.light);
    expect(find.byType(LiquidGlass), findsNothing);

    play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final growing = tester.getSize(find.byType(AudioMiniPlayer)).height;
    await tester.pumpAndSettle();
    final full = tester.getSize(find.byType(AudioMiniPlayer)).height;
    expect(growing, greaterThan(0));
    expect(growing, lessThan(full));

    audio.queue.value = null;
    audio.playingVerse.value = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidGlass), findsNothing);
    expect(tester.getSize(find.byType(AudioMiniPlayer)).height, 0);
  });

  testWidgets('tanpa ripple di atas kaca', (tester) async {
    await pump(tester, AppPalette.sacred, Brightness.dark);
    play();
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Al-Ikhlas · Ayat 2'));
    expect(Theme.of(context).splashFactory, NoSplash.splashFactory);
  });
}
