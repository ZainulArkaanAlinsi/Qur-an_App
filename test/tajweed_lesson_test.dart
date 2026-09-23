import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/learn/data/tajweed_lesson_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Materi contoh memakai kalimat penanda, bukan penjelasan tajwid sungguhan:
/// isi yang sebenarnya ditulis manusia dan diperiksa peninjau, bukan lahir di
/// dalam tes.
String _json({
  String rule = 'idgham_ghunnah',
  String title = '<judul>',
  String summary = '<ringkas>',
  String detail = '<uraian>',
  String reviewedBy = '<peninjau>',
  List<Map<String, Object?>>? examples,
  int count = 1,
}) => jsonEncode({
  'version': 1,
  'source': {
    'title': '<judul sumber>',
    'author': '<penulis>',
    'url': '<pranala>',
    'reviewedBy': reviewedBy,
    'reviewedOn': '2026-09-23',
  },
  'lessons': [
    for (var i = 0; i < count; i++)
      {
        'rule': rule,
        'title': title,
        'summary': summary,
        'detail': detail,
        if (examples != null) 'examples': examples,
      },
  ],
});

void main() {
  test('berkas materi bawaan masih kosong dan tidak dianggap siap', () {
    final book = TajweedLessonRepository.parse(
      File('assets/learn/tajweed_lessons.json').readAsStringSync(),
    );
    expect(book.lessons, isEmpty);
    expect(book.isReady, isFalse);
  });

  test('materi lengkap terbaca beserta hukumnya', () {
    final book = TajweedLessonRepository.parse(
      _json(
        examples: [
          {'surah': 2, 'ayah': 5, 'note': '<keterangan>'},
        ],
      ),
    );
    expect(book.lessons, hasLength(1));
    expect(book.lessons.single.rule, TajweedRule.idghamBighunnah);
    expect(book.lessons.single.examples.single.surah, 2);
    expect(book.isReady, isTrue);
  });

  test('tanpa nama peninjau materi tidak dianggap siap tampil', () {
    final book = TajweedLessonRepository.parse(_json(reviewedBy: '   '));
    expect(book.lessons, hasLength(1));
    expect(book.isReady, isFalse);
  });

  test('hukum di luar daftar yang dikenal ditolak', () {
    expect(
      () => TajweedLessonRepository.parse(_json(rule: 'hukum_karangan')),
      throwsFormatException,
    );
  });

  test('hukum yang ditulis dua kali ditolak', () {
    expect(
      () => TajweedLessonRepository.parse(_json(count: 2)),
      throwsFormatException,
    );
  });

  test('materi setengah jadi ditolak, bukan ditampilkan separuh', () {
    expect(
      () => TajweedLessonRepository.parse(_json(detail: '')),
      throwsFormatException,
    );
  });

  test('nomor ayat di luar jumlah ayat surah ditolak', () {
    expect(
      () => TajweedLessonRepository.parse(
        // Al-Fatihah hanya 7 ayat.
        _json(
          examples: [
            {'surah': 1, 'ayah': 8, 'note': '<keterangan>'},
          ],
        ),
      ),
      throwsFormatException,
    );
  });
}
