import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_follow_list.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_segment_track.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/murottal_screen.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_now_playing_audio.dart';

/// Murottal v6 (docs/design/v6/screens/20-murottal.md "Selesai jika"):
/// perilaku, bukan piksel (piksel di golden 20_murottal_*).
void main() {
  late Directory directory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Aset dibaca sekali di waktu nyata; tes memakai cache-nya.
    await QuranTextRepository.instance.versesForSurah(1);
    await TranslationRepository.instance.forSurah(1);
    await SuraNamesRepository.load();
  });

  setUp(() => directory = Directory.systemTemp.createTempSync('murottal_v6'));
  tearDown(() => directory.deleteSync(recursive: true));

  AudioDownloadService downloads() => AudioDownloadService(
    client: MockClient(
      (_) async =>
          http.Response.bytes([1, 2, 3], 200, headers: {'content-length': '3'}),
    ),
    directory: () async => directory,
  );

  Future<FakeNowPlayingAudio> pump(
    WidgetTester tester, {
    void Function(FakeNowPlayingAudio audio)? setup,
    Map<String, Object> prefs = const {},
    AudioDownloadService? service,
  }) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues(prefs);
      await SharedPreferencesService.init();
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final audio = FakeNowPlayingAudio();
    setup?.call(audio);
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: MurottalScreen(
          audio: audio,
          downloadService: service ?? downloads(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    return audio;
  }

  int activeAyah(WidgetTester tester) => tester
      .widgetList<AyahFollowItem>(find.byType(AyahFollowItem))
      .singleWhere((item) => item.active)
      .ayah;

  Finder item(int ayah) => find.byWidgetPredicate(
    (widget) => widget is AyahFollowItem && widget.ayah == ayah,
  );

  /// Ayat tampil di bagian atas–tengah layar (bukan di luar layar).
  bool onScreen(WidgetTester tester, int ayah) {
    final found = item(ayah);
    if (found.evaluate().isEmpty) return false;
    final rect = tester.getRect(found);
    return rect.top >= 0 && rect.top < 560;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('ayat aktif mengikuti playingVerse dan daftar ikut bergulir', (
    tester,
  ) async {
    final audio = await pump(tester, setup: (a) => a.play(2, 1, toAyah: 40));
    expect(activeAyah(tester), 1);
    expect(find.text('DIPUTAR'), findsOneWidget);

    audio.moveTo(30);
    await settle(tester);
    expect(activeAyah(tester), 30);
    expect(onScreen(tester, 30), isTrue);
    expect(find.text('Ayat 30 dari 40'), findsOneWidget);
  });

  testWidgets('ketuk segmen melompat ke indeks yang benar; geser memilih '
      'ayat saat jari diangkat', (tester) async {
    final audio = await pump(tester, setup: (a) => a.play(1, 1));
    final track = find.byWidgetPredicate(
      (widget) => widget is AyahSegmentTrack && !widget.mini,
    );
    final rect = tester.getRect(track);
    await tester.tapAt(
      Offset(rect.left + rect.width * 4.5 / 7, rect.center.dy),
    );
    await settle(tester);
    expect(audio.jumps, [4]);
    expect(activeAyah(tester), 5);

    await tester.dragFrom(
      Offset(rect.left + rect.width * .5 / 7, rect.center.dy),
      Offset(rect.width * 6 / 7, 0),
    );
    await tester.pump();
    expect(audio.jumps, [4, 6]);
  });

  testWidgets('ketuk ayat di daftar = lompat ke ayat itu', (tester) async {
    // Ayat 2 diputar; ayat 1 di atasnya masih terlihat (di luar panel).
    final audio = await pump(tester, setup: (a) => a.play(1, 2, from: 1));
    await tester.tapAt(
      tester.getRect(item(1)).bottomCenter - const Offset(0, 20),
    );
    await settle(tester);
    expect(audio.jumps, [0]);
    expect(activeAyah(tester), 1);
  });

  testWidgets('gulir manual menghentikan auto-gulir; pill "Kembali" muncul '
      'dan mengembalikan ke ayat yang diputar', (tester) async {
    final audio = await pump(tester, setup: (a) => a.play(2, 1, toAyah: 40));
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -1200),
    );
    await settle(tester);
    expect(find.text('Kembali ke ayat yang diputar'), findsOneWidget);

    // Ayat berganti saat pengguna sedang membaca di tempat lain: daftar
    // tidak ditarik kembali.
    audio.moveTo(2);
    await settle(tester);
    expect(find.text('Ayat 2 dari 40'), findsOneWidget);
    expect(onScreen(tester, 2), isFalse);

    await tester.tap(find.text('Kembali ke ayat yang diputar'));
    await settle(tester);
    expect(find.text('Kembali ke ayat yang diputar'), findsNothing);
    expect(onScreen(tester, 2), isTrue);
  });

  testWidgets('mengikuti lagi sendiri 6 detik setelah gulir manual', (
    tester,
  ) async {
    await pump(tester, setup: (a) => a.play(2, 1, toAyah: 40));
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -600),
    );
    await settle(tester);
    expect(find.text('Kembali ke ayat yang diputar'), findsOneWidget);
    await tester.pump(AyahFollowList.followPause);
    await tester.pump();
    expect(find.text('Kembali ke ayat yang diputar'), findsNothing);
  });

  testWidgets('Unduh memakai AudioDownloadService lalu menjadi Tersimpan', (
    tester,
  ) async {
    final service = downloads();
    await pump(tester, setup: (a) => a.play(112, 1), service: service);
    expect(find.text('Unduh'), findsOneWidget);

    await tester.tap(find.text('Unduh'));
    await tester.pumpAndSettle();
    expect(find.text('Unduh murottal Al-Ikhlas?'), findsOneWidget);
    await tester.tap(find.text('Unduh').last);
    await tester.pumpAndSettle();

    expect(find.text('Tersimpan'), findsOneWidget);
    expect(
      await tester.runAsync(() => service.isComplete(defaultReciter, 112)),
      isTrue,
    );
  });

  testWidgets('Sebelumnya/Berikutnya non-aktif di ujung antrean', (
    tester,
  ) async {
    final audio = await pump(tester, setup: (a) => a.play(1, 1));
    expect(find.bySemanticsLabel('Ayat pertama'), findsOneWidget);
    expect(find.bySemanticsLabel('Ayat berikutnya'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Ayat pertama'));
    await tester.pump();
    expect(audio.previouses, 0);

    audio.moveTo(7);
    await tester.pump();
    expect(find.bySemanticsLabel('Ayat sebelumnya'), findsOneWidget);
    expect(find.bySemanticsLabel('Ayat terakhir'), findsOneWidget);
  });

  testWidgets('Ulang: mati → ayat → rentang (tanpa batas) → mati, '
      'tanpa pindah ayat', (tester) async {
    final audio = await pump(tester, setup: (a) => a.play(1, 3, from: 1));
    Future<void> tapRepeat() async {
      await tester.tap(find.text('Ulang'));
      await tester.pump();
    }

    await tapRepeat();
    expect(audio.repeats, [AudioRepeat.verse]);
    await tapRepeat();
    expect(audio.ranges.last.repeatCount, isNull);
    expect(audio.ranges.last.startAyah, 3);
    expect(find.text('∞'), findsOneWidget);
    await tapRepeat();
    expect(audio.ranges.last.repeatCount, 1);
    expect(audio.ranges.last.startAyah, 3);
    expect(find.text('∞'), findsNothing);
  });

  testWidgets('kecepatan bersiklus dan tampil di tombol', (tester) async {
    final audio = await pump(tester, setup: (a) => a.play(1, 1));
    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.text('1×'));
    await tester.pump();
    expect(audio.speeds, [1.25]);
    expect(find.text('1.25×'), findsOneWidget);
  });

  testWidgets('galat: banner + "Coba lagi" memutar ulang dari ayat yang sama', (
    tester,
  ) async {
    final audio = await pump(tester, setup: (a) => a.play(1, 5, from: 1));
    audio.fail('Murottal terputus. Periksa koneksi internet.');
    await tester.pump();
    const message =
        'Murottal belum dapat diputar. Periksa koneksi atau unduh surah ini.';
    expect(find.text(message), findsOneWidget);
    expect(find.text('Ayat 5 dari 7'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    final retry = audio.ranges.single;
    expect((retry.surah, retry.fromAyah, retry.toAyah), (1, 1, 7));
    expect(retry.startAyah, 5);
    expect(find.text(message), findsNothing);
  });

  testWidgets('Teks | Sampul disimpan; Sampul hanya menampilkan ayat aktif', (
    tester,
  ) async {
    await pump(tester, setup: (a) => a.play(1, 5, from: 1));
    expect(find.byType(AyahFollowItem), findsWidgets);
    await tester.tap(find.text('Sampul'));
    await tester.pump();
    expect(find.byType(AyahFollowItem), findsOneWidget);
    expect(activeAyah(tester), 5);
    expect(SharedPreferencesService.getMurottalView(), 'sampul');
  });

  testWidgets('tidak diputar: tawarkan bacaan terakhir; tanpa teks internal', (
    tester,
  ) async {
    final audio = await pump(
      tester,
      prefs: {'last_read_surah': 18, 'last_read_verse_18': 23},
    );
    expect(find.text('Murottal sedang tidak diputar'), findsOneWidget);
    expect(find.textContaining('Waktu mendengar'), findsNothing);
    await tester.tap(find.textContaining('dari ayat 23'));
    await tester.pump();
    expect(audio.playedFrom, [(18, 23)]);
    expect(find.text('Ayat 23 · 1 dari 88'), findsOneWidget);
  });
}
