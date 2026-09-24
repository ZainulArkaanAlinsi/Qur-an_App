import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/online_translations.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/screens/translation_picker.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('quran_picker_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, MockClient client) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.light,
        home: TranslationPicker(
          library: OnlineTranslations(
            client: client,
            directory: () async => temp,
            timeout: const Duration(seconds: 2),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('luring: pesan jelas, terjemahan bawaan tetap ada', (
    tester,
  ) async {
    await pump(
      tester,
      MockClient((_) async => throw const SocketException('offline')),
    );
    expect(find.textContaining('butuh internet'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Bahasa Indonesia'), findsOneWidget);
  });

  testWidgets('Unduh lalu pindah ke Tersimpan', (tester) async {
    await pump(
      tester,
      MockClient((request) async {
        if (request.url.host == 'quranenc.com') return _json('', 503);
        if (request.url.path.endsWith('editions.json')) {
          return _json({
            'eng_ummmuhammad': {
              'name': 'eng-ummmuhammad',
              'author': 'Umm Muhammad',
              'language': 'English',
              'direction': 'ltr',
            },
          });
        }
        return _json({
          'quran': [
            for (final meta in surahCatalog)
              for (var ayah = 1; ayah <= meta.ayahCount; ayah++)
                {'chapter': meta.number, 'verse': ayah, 'text': 't'},
          ],
        });
      }),
    );
    expect(find.textContaining('sumber cadangan fawazahmed0'), findsOneWidget);
    expect(find.text('Unduh'), findsOneWidget);

    await tester.tap(find.text('Unduh'));
    for (var i = 0; i < 6 && find.text('Unduh').evaluate().isNotEmpty; i++) {
      await _settle(tester);
    }
    // Tunggu daftar tersimpan dimuat ulang.
    await _settle(tester);

    expect(find.text('Unduh'), findsNothing);
    expect(find.text('Umm Muhammad'), findsOneWidget);
    expect(find.text('Semua terjemahan sudah tersimpan'), findsOneWidget);
  });
}
