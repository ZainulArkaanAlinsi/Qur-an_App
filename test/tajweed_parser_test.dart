import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

Map<String, String> _loadFixture() {
  final json =
      jsonDecode(
            File(
              'test/fixtures/qf_uthmani_tajweed_sample.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    for (final verse in json['verses'] as List)
      verse['verse_key'] as String: verse['text_uthmani_tajweed'] as String,
  };
}

/// Implementasi pembanding yang sengaja naif: hapus penanda akhir ayat lalu
/// semua tag. Parser harus menghasilkan teks yang identik byte-per-byte.
String _naiveStrip(String markup) => markup
    .replaceAll(RegExp(r'<span class=end>.*?</span>'), '')
    .replaceAll(RegExp(r'<[^>]+>'), '');

void main() {
  const parser = TajweedMarkupParser();
  final fixture = _loadFixture();

  test('teks polos identik dengan markup tanpa tag untuk setiap ayat', () {
    for (final MapEntry(key: key, value: markup) in fixture.entries) {
      final verse = parser.parse(key, markup);
      expect(verse.text, _naiveStrip(markup), reason: key);
      expect(verse.rejectedClasses, isEmpty, reason: key);
      expect(verse.endMarker, isNotNull, reason: key);
    }
  });

  test('runs menutup seluruh teks tanpa celah atau tumpang tindih', () {
    for (final MapEntry(key: key, value: markup) in fixture.entries) {
      final verse = parser.parse(key, markup);
      var offset = 0;
      final rebuilt = StringBuffer();
      for (final run in verse.runs) {
        expect(run.start, offset, reason: key);
        expect(run.end, greaterThan(run.start), reason: key);
        rebuilt.write(verse.text.substring(run.start, run.end));
        offset = run.end;
      }
      expect(offset, verse.text.length, reason: key);
      expect(rebuilt.toString(), verse.text, reason: key);
    }
  });

  test('Al-Fatihah 1: jumlah hukum dan nomor ayat', () {
    final verse = parser.parse('1:1', fixture['1:1']!);
    expect(verse.ruleCounts, {
      TajweedRule.hamzahWasl: 3,
      TajweedRule.lamSyamsiyah: 2,
      TajweedRule.madThabii: 1,
      TajweedRule.madJaiz: 1,
    });
    expect(verse.endMarker, '١');
  });

  test(
    'tag bersarang: hukum terdalam menang saat dirender, keduanya dihitung',
    () {
      final verse = parser.parse('2:190', fixture['2:190']!);
      final outer = verse.segments.firstWhere(
        (s) => s.rule == TajweedRule.madWajib,
      );
      final inner = verse.segments.firstWhere(
        (s) => s.rule == TajweedRule.silent && s.start >= outer.start,
      );
      expect(inner.depth, outer.depth + 1);
      expect(inner.end, lessThanOrEqualTo(outer.end));

      final runAtInner = verse.runs.firstWhere(
        (r) => r.start <= inner.start && r.end > inner.start,
      );
      expect(runAtInner.rule, TajweedRule.silent);
      final runAtOuterStart = verse.runs.firstWhere(
        (r) => r.start <= outer.start && r.end > outer.start,
      );
      expect(runAtOuterStart.rule, TajweedRule.madWajib);
    },
  );

  test('class di luar whitelist ditolak tanpa mengubah teks', () {
    final verse = parser.parse(
      'x:1',
      'ab<tajweed class=unknown_rule>cd</tajweed>e<span class=end>1</span>',
    );
    expect(verse.text, 'abcde');
    expect(verse.segments, isEmpty);
    expect(verse.rejectedClasses, {'unknown_rule'});
  });

  test('class boleh memakai tanda kutip', () {
    final verse = parser.parse('x:1', 'a<tajweed class="ikhafa">b</tajweed>');
    expect(verse.segments.single.rule, TajweedRule.ikhfaHaqiqi);
    expect(verse.endMarker, isNull);
  });

  test('cacat nyata provider (32:3, tag pembuka hilang) ditolak', () {
    final json =
        jsonDecode(
              File(
                'test/fixtures/qf_uthmani_tajweed_sample.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final verse = (json['malformed_verses'] as List).single as Map;
    expect(
      () => parser.parse(
        verse['verse_key'] as String,
        verse['text_uthmani_tajweed'] as String,
      ),
      throwsFormatException,
    );
  });

  group('markup rusak ditolak', () {
    for (final (label, markup) in [
      ('tag tidak ditutup', 'a<tajweed class=ikhafa>b'),
      ('penutup tanpa pembuka', 'a</tajweed>b'),
      ('tag asing', 'a<b>c</b>'),
      ('teks setelah akhir ayat', 'a<span class=end>1</span>b'),
      ('span selain end', 'a<span class=x>1</span>'),
      (
        'tajwid di dalam penanda ayat',
        'a<span class=end><tajweed class=ikhafa>1</tajweed></span>',
      ),
    ]) {
      test(label, () {
        expect(() => parser.parse('x:1', markup), throwsFormatException);
      });
    }
  });
}
