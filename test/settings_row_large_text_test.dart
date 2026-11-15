// Teks besar: baris pengaturan tidak boleh memotong namanya.
//
// Temuan 14 November 2026 di emulator (font sistem 200%): di tab Saya, judul
// "Terjemahan" tampil "Terjem…" dan "Warna tajwid" tampil "Warna …" karena
// nilai di kanan merebut lebar baris. Pembaca dengan teks besar jadi tidak
// bisa membaca nama pengaturannya (WCAG 1.4.4).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';

import 'golden/golden_harness.dart' show loadAppFonts;

Future<void> _pump(
  WidgetTester tester, {
  required double textScale,
  required String title,
  required String value,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ListView(
            shrinkWrap: true,
            children: [
              SettingsRow(
                icon: SacredIcons.book,
                chipColor: const Color(0xFF2E6F8E),
                title: title,
                value: value,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _truncated(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

void main() {
  // Font asli wajib dimuat; font uji bawaan (Ahem) selebar kotak dan memotong semuanya.
  setUpAll(loadAppFonts);

  // Pasangan judul + nilai yang benar-benar ada di tab Saya.
  const rows = [
    ('Terjemahan', 'Unduh bahasa lain'),
    ('Warna tajwid', 'Arti tiap warna'),
    ('Tampilan teks', '28 pt'),
  ];

  for (final (title, value) in rows) {
    testWidgets('teks 200%: "$title" dan nilainya terbaca utuh', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, title: title, value: value);
      expect(_truncated(tester, title), isFalse, reason: 'judul terpotong');
      expect(_truncated(tester, value), isFalse, reason: 'nilai terpotong');
    });

    testWidgets('teks normal: "$title" dan nilainya tetap satu baris sejajar', (
      tester,
    ) async {
      await _pump(tester, textScale: 1, title: title, value: value);
      expect(_truncated(tester, title), isFalse);
      expect(_truncated(tester, value), isFalse);
      final titleY = tester.getCenter(find.text(title)).dy;
      final valueY = tester.getCenter(find.text(value)).dy;
      expect(
        (titleY - valueY).abs(),
        lessThan(6),
        reason: 'di skala normal nilai harus tetap sebaris dengan judul',
      );
    });
  }
}
