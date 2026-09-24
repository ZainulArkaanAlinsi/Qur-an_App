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
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

/// Katalog berbentuk respons QuranEnc (judul "Bahasa - Penerjemah").
const _catalog = [
  ('indonesian_complex', 'id', 'Indonesian - King Fahd Complex'),
  ('english_saheeh', 'en', 'English - Saheeh International'),
  ('english_rwwad', 'en', 'English - Rowwad Translation Center'),
  ('french_rashid', 'fr', 'French - Rashid Maash'),
  ('spanish_garcia', 'es', 'Spanish - Isa Garcia'),
  ('german_rwwad', 'de', 'German - Rowwad Translation Center'),
  ('turkish_rwwad', 'tr', 'Turkish - Rowwad Translation Center'),
  ('japanese_saeedsato', 'ja', 'Japanese - Saeed Sato'),
  ('urdu_junagarhi', 'ur', 'Urdu - Muhammad Junagarhi'),
];

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient _client() => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/translations/list')) {
    return _json({
      'translations': [
        for (final (key, lang, title) in _catalog)
          {
            'key': key,
            'language_iso_code': lang,
            'title': title,
            'version': '1.0.0',
            'direction': lang == 'ur' ? 'rtl' : 'ltr',
          },
      ],
    });
  }
  final surah = int.parse(request.url.pathSegments.last);
  return _json({
    'result': [
      for (var a = 1; a <= surahCatalog[surah - 1].ayahCount; a++)
        {'aya': '$a', 'translation': 'teks $surah:$a'},
    ],
  });
});

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
    temp = await Directory.systemTemp.createTemp('quran_bahasa_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  for (final variant in GoldenVariant.all) {
    testWidgets('06 bahasa · ${variant.suffix}', (tester) async {
      final library = OnlineTranslations(
        client: _client(),
        directory: () async => temp,
      );
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferencesService.init();
        // English · Saheeh International sudah diunduh dan dipakai.
        final saved = await library.download(
          const TranslationEdition(
            provider: TranslationProvider.quranEnc,
            id: 'english_saheeh',
            title: 'English - Saheeh International',
            language: 'en',
            version: '1.0.0',
          ),
        );
        await saveSecondTranslation(saved);
      });

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
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SacredTheme.themeFor(AppPalette.sacred, variant.brightness),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(variant.textScale)),
            child: app!,
          ),
          home: TranslationPicker(library: library, backLabel: 'Kartu'),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Pilih maksimal 2 · 8 bahasa'), findsOneWidget);
      if (variant.textScale == 1) {
        // Nama bahasa dalam aksaranya sendiri, subjudul nama penerjemah.
        expect(find.text('Saheeh International'), findsOneWidget);
        expect(find.text('Français'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp('^English, Saheeh International, dipakai'),
          ),
          findsOneWidget,
        );
      }
      expectNotTruncated(tester, [
        'Terjemahan',
        'Kartu',
        'Bahasa Indonesia',
        'Unduh',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/06_bahasa_${variant.suffix}.png'),
      );
    });
  }
}
