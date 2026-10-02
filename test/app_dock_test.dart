import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/widgets/app_dock.dart';
import 'package:quran_app_2025/app/widgets/lintasan.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_segment_track.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

import 'support/fake_now_playing_audio.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

Future<void> _pumpDock(
  WidgetTester tester, {
  required FakeNowPlayingAudio audio,
  ValueNotifier<double>? reserved,
  int index = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AppDock(
            tabs: _tabs,
            currentIndex: index,
            onSelected: onSelected ?? (_) {},
            audio: audio,
            reserved: reserved,
            onOpenPlayer: onOpen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tinggi permukaan kaca dock (kaca terluar, bukan lensa tab).
double _dockHeight(WidgetTester tester) =>
    tester.getSize(find.byType(LiquidGlass).first).height;

void main() {
  group('AppDock', () {
    testWidgets('tanpa murottal: hanya tab, tinggi 64', (tester) async {
      await _pumpDock(tester, audio: FakeNowPlayingAudio());
      expect(_dockHeight(tester), AppDock.tabsHeight);
      expect(find.textContaining('Ayat'), findsNothing);
      for (final tab in _tabs) {
        expect(find.text(tab.label), findsOneWidget);
      }
    });

    testWidgets('murottal diputar: baris muncul, dock 64 → 135', (
      tester,
    ) async {
      final audio = FakeNowPlayingAudio();
      await _pumpDock(tester, audio: audio);
      audio.play(1, 3);
      await tester.pumpAndSettle();
      expect(find.text('Al-Fatihah · Ayat 3'), findsOneWidget);
      expect(find.text('Hudhaify · per ayat'), findsOneWidget);
      expect(
        _dockHeight(tester),
        AppDock.tabsHeight + AppDock.nowPlayingHeight,
      );
    });

    testWidgets('ruang bawah halaman ikut berubah saat dock memanjang', (
      tester,
    ) async {
      final audio = FakeNowPlayingAudio();
      final reserved = ValueNotifier<double>(AppDock.defaultReserved);
      addTearDown(reserved.dispose);
      await _pumpDock(tester, audio: audio, reserved: reserved);
      expect(reserved.value, AppDock.defaultReserved);

      audio.play(1, 3);
      await tester.pumpAndSettle();
      expect(
        reserved.value,
        AppDock.defaultReserved + AppDock.nowPlayingHeight,
      );

      await audio.stop();
      await tester.pumpAndSettle();
      expect(reserved.value, AppDock.defaultReserved);
    });

    testWidgets('geser bawah menghentikan; Urungkan memulihkan', (
      tester,
    ) async {
      final audio = FakeNowPlayingAudio()..play(1, 3);
      await _pumpDock(tester, audio: audio);

      await tester.drag(find.text('Al-Fatihah · Ayat 3'), const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(audio.stops, 1);
      expect(_dockHeight(tester), AppDock.tabsHeight);
      expect(find.text('Murottal dihentikan'), findsOneWidget);

      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(audio.restored?.surah, 1);
      expect(audio.restored?.ayah, 3);
      expect(find.text('Al-Fatihah · Ayat 3'), findsOneWidget);
    });

    testWidgets('ketuk atau geser atas membuka pemutar', (tester) async {
      var opened = 0;
      final audio = FakeNowPlayingAudio()..play(1, 3);
      await _pumpDock(tester, audio: audio, onOpen: () => opened++);

      await tester.tap(find.text('Al-Fatihah · Ayat 3'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Al-Fatihah · Ayat 3'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(audio.stops, 0);
    });

    testWidgets('tombol putar/jeda dan berikutnya ke pemutar', (tester) async {
      final audio = FakeNowPlayingAudio()..play(1, 3);
      await _pumpDock(tester, audio: audio);
      await tester.tap(find.byTooltip('Jeda'));
      await tester.tap(find.byTooltip('Ayat berikutnya'));
      await tester.pumpAndSettle();
      expect(audio.toggles, 1);
      expect(audio.nexts, 1);
    });

    testWidgets('ketuk tab dan geser lensa memilih tab', (tester) async {
      final picked = <int>[];
      await _pumpDock(
        tester,
        audio: FakeNowPlayingAudio(),
        onSelected: picked.add,
      );
      await tester.tap(find.text('Hafalan'));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.text('Beranda'),
        tester.getCenter(find.text('Saya')) -
            tester.getCenter(find.text('Beranda')),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(picked, [3, 4]);
    });

    testWidgets('sub-judul mengikuti status pemutar', (tester) async {
      final audio = FakeNowPlayingAudio()..play(78, 12, from: 1, toAyah: 20);
      audio
        ..repeat = AudioRepeat.range
        ..rangePass = 2
        ..rangeTarget = 3;
      await _pumpDock(tester, audio: audio);
      expect(find.text('Rentang 1–20 · 2/3'), findsOneWidget);

      audio
        ..repeat = AudioRepeat.off
        ..buffering = true
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Memuat…'), findsOneWidget);

      audio
        ..buffering = false
        ..sourceNote = 'cadangan'
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Sumber cadangan'), findsOneWidget);
    });

    testWidgets('label tab tidak terpotong di teks 1.3 dan layar 320', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final audio = FakeNowPlayingAudio()..play(2, 255);
      await tester.pumpWidget(
        MaterialApp(
          theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: app!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppDock(
                tabs: _tabs,
                currentIndex: 1,
                onSelected: (_) {},
                audio: audio,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Lintasan & segmen ayat', () {
    test('titik berjarak sama, 12 dari tepi', () {
      final xs = Lintasan.dotPositions(390, 5);
      expect(xs.first, Lintasan.edge);
      expect(xs.last, 390 - Lintasan.edge);
      expect(xs[2] - xs[1], closeTo(xs[1] - xs[0], 1e-9));
    });

    test('bar kontinu tidak pernah > 1 dan mulai di 0', () {
      expect(AyahSegmentTrack.continuousFill(41, 0, 0), 0);
      expect(AyahSegmentTrack.continuousFill(41, 40, 1), 1);
      expect(AyahSegmentTrack.continuousFill(41, 40, 3), 1);
      expect(AyahSegmentTrack.continuousFill(0, 0, .5), 0);
    });

    test('batas segmen 40 ayat', () {
      expect(AyahSegmentTrack.segmentLimit, 40);
    });
  });
}
