import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/qari_catalog.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Pemilih qari v6.1 (docs/design/v6/screens/23-qari.md): acuan
/// V6-Qari.png (rilis, filter Adem, Hudhaify dipilih) dan
/// V6-Qari-Debug-Gelap.png (debug, semua sumber).
final _catalog = QariCatalog.parse(File(QariCatalog.asset).readAsStringSync());

ReciterRepository _repository() => ReciterRepository(
  client: MockClient((request) async {
    if (request.method == 'HEAD') return http.Response('', 200);
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'data': [
            {
              'identifier': 'ar.hudhaify',
              'name': 'علي بن عبدالرحمن الحذيفي',
              'englishName': 'Hudhaify',
              'language': 'ar',
            },
          ],
        }),
      ),
      200,
    );
  }),
);

class _FakePreview {
  final playing = ValueNotifier(false);
  final played = <String>[];
  int stops = 0;

  PreviewPlayer get player => PreviewPlayer(
    isPlaying: playing,
    play: (reciter) async {
      played.add(reciter.identifier);
      playing.value = true;
    },
    stop: () async {
      stops++;
      playing.value = false;
    },
  );
}

Future<void> _prefs(WidgetTester tester, {String filter = 'adem'}) =>
    tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'qari.filter': filter});
      await SharedPreferencesService.init();
      await SharedPreferencesService.setReciter(
        const Reciter(
          identifier: 'ar.hudhaify',
          name: '',
          englishName: 'Hudhaify',
          bitrate: 128,
        ),
      );
    });

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  for (final (name, variant, debug) in [
    ('light', const GoldenVariant(Brightness.light, 1), false),
    ('dark', const GoldenVariant(Brightness.dark, 1), false),
    ('light_x2', const GoldenVariant(Brightness.light, 2), false),
    ('debug_dark', const GoldenVariant(Brightness.dark, 1), true),
  ]) {
    testWidgets('23 qari · $name', (tester) async {
      await _prefs(tester);
      await pumpGolden(
        tester,
        ReciterPicker(
          repository: _repository(),
          player: _FakePreview().player,
          catalog: Future.value(_catalog),
          allowPending: debug,
          reloadQueue: () async {},
        ),
        variant: variant,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final expected = [
        'Pilih qari',
        'Semua',
        'Adem',
        'Ali Al-Hudhaify',
        if (debug) ...[
          'Abdul Muhsin Al-Qasim',
          'MENUNGGU IZIN',
          'semua sumber',
        ] else ...[
          'ADEM · 8 QARI',
          'Maher Al-Muaiqly',
          'Haramain',
          'berizin',
        ],
      ];
      for (final text in expected) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expectNotTruncated(tester, expected);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/23_qari_$name.png'),
      );
    });
  }

  group('perilaku', () {
    late _FakePreview preview;
    late int reloads;

    Future<void> open(
      WidgetTester tester, {
      bool debug = false,
      String filter = 'adem',
    }) async {
      await _prefs(tester, filter: filter);
      preview = _FakePreview();
      reloads = 0;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
          home: ReciterPicker(
            repository: _repository(),
            player: preview.player,
            catalog: Future.value(_catalog),
            allowPending: debug,
            reloadQueue: () async => reloads++,
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('rilis: qari tanpa sumber berizin tidak pernah tampil', (
      tester,
    ) async {
      await open(tester, filter: 'populer');
      expect(find.text('Mishary Rashid Alafasy'), findsOneWidget);
      expect(find.text('Yasser Al-Dosari'), findsNothing);
      expect(find.text('MENUNGGU IZIN'), findsNothing);
    });

    testWidgets('chip filter tersimpan di qari.filter', (tester) async {
      await open(tester);
      // Chip ada di atas tag baris.
      await tester.tap(find.text('Hafalan').first);
      await tester.pump();
      expect(SharedPreferencesService.getQariFilter(), 'hafalan');
      expect(find.textContaining('HAFALAN ·'), findsOneWidget);
    });

    testWidgets('pilih qari: tersimpan lalu antrean dimuat ulang', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Maher Al-Muaiqly'));
      await _settle(tester);
      expect(
        SharedPreferencesService.getReciter().identifier,
        'ar.mahermuaiqly',
      );
      expect(SharedPreferencesService.getReciter().bitrate, 128);
      expect(reloads, 1);
    });

    testWidgets('dengar contoh: hanya satu, ketuk lagi berhenti', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Dengar contoh Maher Al-Muaiqly'));
      await _settle(tester);
      await tester.tap(
        find.bySemanticsLabel('Dengar contoh Mahmoud Khalil Al-Husary'),
      );
      await _settle(tester);
      expect(preview.played, ['ar.mahermuaiqly', 'ar.husary']);
      expect(find.bySemanticsLabel(RegExp('^Hentikan contoh')), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel('Hentikan contoh Mahmoud Khalil Al-Husary'),
      );
      await _settle(tester);
      expect(preview.stops, 1);
      expect(find.bySemanticsLabel(RegExp('^Hentikan contoh')), findsNothing);
    });

    testWidgets('debug: qari menunggu izin tampil, belum bisa dipilih', (
      tester,
    ) async {
      await open(tester, debug: true);
      expect(find.textContaining('Build debug'), findsOneWidget);
      await tester.tap(find.text('Ali Jaber'));
      await tester.pump();
      expect(find.textContaining('masih menunggu izin'), findsOneWidget);
      expect(SharedPreferencesService.getReciter().identifier, 'ar.hudhaify');
    });
  });
}
