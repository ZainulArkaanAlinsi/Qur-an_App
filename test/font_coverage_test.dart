import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Memeriksa tabel `cmap` font tanpa pustaka tambahan: pemetaan karakter ke
/// glyph cukup untuk memastikan tidak ada tanda baca Al-Qur'an yang hilang.
Set<int> _codepointsOf(String path) {
  final bytes = File(path).readAsBytesSync().buffer.asByteData();
  final tableCount = bytes.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(
      List.generate(4, (n) => bytes.getUint8(record + n)),
    );
    if (tag == 'cmap') cmapOffset = bytes.getUint32(record + 8);
  }
  if (cmapOffset < 0) return {};

  final subtables = bytes.getUint16(cmapOffset + 2);
  final codepoints = <int>{};
  for (var i = 0; i < subtables; i++) {
    final encoding = cmapOffset + 4 + i * 8;
    final subtable = cmapOffset + bytes.getUint32(encoding + 4);
    if (bytes.getUint16(subtable) != 4) continue; // format 4 saja
    final segCount = bytes.getUint16(subtable + 6) ~/ 2;
    final endBase = subtable + 14;
    final startBase = endBase + segCount * 2 + 2;
    final deltaBase = startBase + segCount * 2;
    final rangeBase = deltaBase + segCount * 2;
    for (var seg = 0; seg < segCount; seg++) {
      final end = bytes.getUint16(endBase + seg * 2);
      final start = bytes.getUint16(startBase + seg * 2);
      if (start == 0xFFFF) continue;
      final delta = bytes.getInt16(deltaBase + seg * 2);
      final rangeOffset = bytes.getUint16(rangeBase + seg * 2);
      for (var code = start; code <= end && code != 0xFFFF; code++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (code + delta) & 0xFFFF;
        } else {
          final index = rangeBase + seg * 2 + rangeOffset + (code - start) * 2;
          if (index + 1 >= bytes.lengthInBytes) continue;
          glyph = bytes.getUint16(index);
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) codepoints.add(code);
      }
    }
  }
  return codepoints;
}

void main() {
  final text = File(
    'assets/quran/raw/tanzil_uthmani_v1.0.2.txt',
  ).readAsStringSync();
  final needed = {
    for (final rune in text.runes)
      if (rune > 0x20) rune,
  };

  test('dataset memakai lebih dari sekadar huruf dasar', () {
    // Menjaga tes ini tetap bermakna bila dataset diganti.
    expect(needed.length, greaterThan(50));
  });

  for (final font in ['AmiriQuran-Regular.ttf', 'Amiri-Regular.ttf']) {
    test("$font memuat setiap karakter teks Al-Qur'an", () {
      final covered = _codepointsOf('assets/fonts/$font');
      final missing = needed.difference(covered).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'Glyph hilang: ${missing.map((c) => '0x${c.toRadixString(16)}')}',
      );
    });
  }

  test('font UI yang dibundel memuat huruf Latin dan tanda baca Indonesia', () {
    final covered = _codepointsOf(
      'assets/fonts/PlusJakartaSans-wght-Latin.ttf',
    );
    for (final char in 'AaZz0123456789.,:;·—’“”'.runes) {
      expect(
        covered,
        contains(char),
        reason: '0x${char.toRadixString(16)} tidak ada',
      );
    }
  });
}
