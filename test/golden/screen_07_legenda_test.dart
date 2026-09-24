import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_legend_screen.dart';

import 'golden_harness.dart';

void main() {
  late List<List<String>> tanzil;

  setUpAll(() {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    var cursor = 0;
    tanzil = [
      for (final meta in surahCatalog)
        lines.sublist(cursor, cursor += meta.ayahCount),
    ];
  });

  Future<String> verse(int surah, int ayah) async =>
      tanzil[surah - 1][ayah - 1];

  /// Token ke-[i] (mulai 1, tanda waqaf ikut dihitung) langsung dari berkas
  /// Tanzil. Nilai pembanding tidak diketik: urutan harakat hasil ketikan
  /// bisa berbeda dari dataset.
  String raw(int surah, int ayah, int i) =>
      tanzil[surah - 1][ayah - 1].split(' ')[i - 1];

  test('contoh diambil persis dari Tanzil, tanda waqaf dilewati', () {
    // 2:256: token ke-5 adalah tanda waqaf, jadi kata ke-5 dan ke-6 adalah
    // token ke-6 dan ke-7.
    expect(
      tajweedExampleText(tanzil[1][255], const TajweedExample(2, 256, 5, 2)),
      '${raw(2, 256, 6)} ${raw(2, 256, 7)}',
    );
    expect(
      tajweedExampleText(tanzil[112][0], const TajweedExample(113, 1, 8)),
      raw(113, 1, 8),
    );
    expect(
      tajweedExampleText(tanzil[0][6], const TajweedExample.lastWord(1, 7)),
      tanzil[0][6].split(' ').last,
    );
    // Rujukan di luar ayat tidak mengarang kata.
    expect(
      tajweedExampleText(tanzil[0][0], const TajweedExample(1, 1, 9)),
      isNull,
    );
  });

  test('setiap hukum tajwid punya tempat di legenda', () {
    final listed = {
      for (final (_, rows) in tajweedLegendGroups)
        for (final (rule, _) in rows) rule,
    };
    expect(listed, TajweedRule.values.toSet());
  });

  for (final variant in GoldenVariant.all) {
    testWidgets('07 legenda · ${variant.suffix}', (tester) async {
      await pumpGolden(
        tester,
        TajweedLegendScreen(verses: verse),
        variant: variant,
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Warna tajwid'), findsOneWidget);
      // Pada teks 2× baris pertama berada di bawah layar (belum dibangun).
      if (variant.textScale == 1) {
        expect(find.text('${raw(2, 5, 4)} ${raw(2, 5, 5)}'), findsOneWidget);
      }
      expectNotTruncated(tester, [
        'Warna tajwid',
        'Idgham Bilaghunnah',
        'Idgham Bighunnah',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/07_legenda_${variant.suffix}.png'),
      );
    });
  }
}
