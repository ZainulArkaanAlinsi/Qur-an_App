import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_explanations.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_rule_sheet.dart';

TajweedExplanation _explanation({
  String? text = 'contoh',
  ContentReviewStatus status = ContentReviewStatus.draft,
  List<String> reviewers = const [],
}) => TajweedExplanation(
  rule: TajweedRule.ghunnah,
  howToRead: text,
  status: status,
  reviewers: reviewers,
);

void main() {
  group('aturan tampil penjelasan (tata kelola konten)', () {
    test('draf tidak tampil di build rilis, boleh di debug', () {
      final draft = _explanation();
      expect(draft.visible(debug: false), isFalse);
      expect(draft.visible(debug: true), isTrue);
      expect(draft.publishable, isFalse);
    });

    test('terbit dengan dua reviewer tampil di rilis', () {
      final ok = _explanation(
        status: ContentReviewStatus.published,
        reviewers: ['Guru A', 'Guru B'],
      );
      expect(ok.visible(debug: false), isTrue);
    });

    test('terbit tapi baru satu reviewer: tidak tampil di rilis', () {
      final one = _explanation(
        status: ContentReviewStatus.published,
        reviewers: ['Guru A'],
      );
      expect(one.visible(debug: false), isFalse);
    });

    test('tanpa teks tidak pernah tampil', () {
      expect(_explanation(text: '  ').visible(debug: true), isFalse);
      expect(_explanation(text: null).visible(debug: true), isFalse);
    });
  });

  test('berkas konten memuat 17 hukum dan belum berisi teks', () async {
    final raw = File(
      'assets/learn/tajweed_explanations.json',
    ).readAsStringSync();
    final loaded = await TajweedExplanations(loadAsset: () async => raw).load();
    expect(loaded.keys.toSet(), TajweedRule.values.toSet());
    // Penjelasan hanya boleh diisi guru tajwid; aplikasi tidak mengarang.
    for (final explanation in loaded.values) {
      expect(explanation.howToRead, isNull, reason: '${explanation.rule}');
      expect(explanation.status, ContentReviewStatus.draft);
    }
    expect((jsonDecode(raw) as Map)['note'], contains('guru tajwid'));
  });

  test('kata yang memuat hukum di ayat, tanpa basmalah bawaan', () async {
    final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    var cursor = 0;
    final tanzil = [
      for (final meta in surahCatalog)
        lines.sublist(cursor, cursor += meta.ayahCount),
    ];
    final repository = TajweedRepository(
      loadAsset: () async => File(
        'assets/quran/raw/tajweed_cpfair_tanzil_v1.0.2.json',
      ).readAsStringSync(),
      verses: (surah) async => tanzil[surah - 1],
    );
    final ikhlas = (await repository.forSurah(112)).first;
    final from = basmalahPrefix(112, ikhlas.text, tanzil[0][0]);
    final words = tajweedRuleWords(ikhlas, TajweedRule.qalqalah, from: from);
    // Qalqalah di 112:1 hanya pada kata terakhir; teks diambil dari dataset.
    expect(words, hasLength(1));
    final (start, end) = words.single;
    expect(ikhlas.text.substring(start, end), ikhlas.text.split(' ').last);
    // Hukum di dalam basmalah tidak ikut dihitung sebagai bagian ayat.
    for (final (s, _) in tajweedRuleWords(
      ikhlas,
      TajweedRule.hamzahWasl,
      from: from,
    )) {
      expect(s, greaterThanOrEqualTo(from));
    }
  });
}
