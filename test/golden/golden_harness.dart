import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';

/// Ukuran acuan mockup v2 (docs/design/v2/screens/*.png berukuran 2×).
const phone = Size(390, 844);
const phoneLandscape = Size(844, 390);

/// Bilah status dan bilah gestur yang dianggap ada di layar acuan: judul
/// mockup mulai di y=58 (47 + 11) dan tab bar 24 dari bawah.
const statusBar = 47.0;
const gestureBar = 24.0;

/// Memuat semua font di FontManifest (Plus Jakarta Sans, EB Garamond,
/// Amiri Quran, ikon Material) supaya golden memakai huruf yang sebenarnya.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Satu varian golden: tema dan skala teks.
class GoldenVariant {
  const GoldenVariant(this.brightness, this.textScale);

  final Brightness brightness;
  final double textScale;

  String get suffix =>
      '${brightness == Brightness.dark ? 'dark' : 'light'}'
      '${textScale == 1 ? '' : '_x${textScale.toStringAsFixed(0)}'}';

  static const all = [
    GoldenVariant(Brightness.light, 1),
    GoldenVariant(Brightness.dark, 1),
    GoldenVariant(Brightness.light, 2),
  ];
}

/// Mode bahan screenshot Play Store (`--dart-define=STORE_SHOTS=true`):
/// bayangan dirender sungguhan dan gambar ditulis ke `build/store_shots/`,
/// bukan dibandingkan dengan golden (lihat flutter_test_config.dart).
const storeShots = bool.fromEnvironment('STORE_SHOTS');

/// Memasang [child] di layar 390×844 (atau [size]) dengan tema aplikasi.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  GoldenVariant variant = const GoldenVariant(Brightness.light, 1),
  Size size = phone,
  AppPalette palette = AppPalette.sacred,
}) async {
  tester.view.physicalSize = size * 3;
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
  // Tes biasa mematikan blur bayangan; screenshot toko memakai bayangan asli.
  // Dikembalikan oleh pembanding store shots setelah gambar diambil.
  if (storeShots) debugDisableShadows = false;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SacredTheme.themeFor(palette, variant.brightness),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(variant.textScale)),
        child: app!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Mendekode semua [Image] yang sedang tampil (logo di splash/onboarding).
/// Dekode gambar butuh waktu nyata, jadi dijalankan di luar waktu semu.
Future<void> loadImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

/// Semua teks yang tampil terpotong (elipsis atau melebihi maxLines).
List<String> truncatedTexts(WidgetTester tester) {
  final result = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is RenderParagraph && render.didExceedMaxLines) {
      result.add(render.text.toPlainText());
    }
  }
  return result;
}

/// Gagal bila salah satu [labels] wajib tampil terpotong.
void expectNotTruncated(WidgetTester tester, Iterable<String> labels) {
  final cut = truncatedTexts(tester).toSet();
  final offending = labels.where(cut.contains).toList();
  expect(offending, isEmpty, reason: 'Label wajib terpotong: $offending');
}
