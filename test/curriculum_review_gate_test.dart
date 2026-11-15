// Gerbang penerbitan materi tajwid dan audio contoh.
//
// Aturan proyek (docs/RELIGIOUS_CONTENT_GOVERNANCE.md): materi hukum tajwid
// hanya boleh terbit setelah diperiksa dua peninjau kompeten, dan contoh
// bunyi wajib rekaman manusia berizin. Parser kurikulum hanya memeriksa
// bahwa pelajaran terbit punya rujukan; tes ini menambahkan dua pemeriksaan
// supaya aturan itu tidak bergantung pada ingatan.
//
// Format catatan peninjau pada pelajaran (sejajar dengan
// assets/learn/tajweed_explanations.json):
//   "reviewers": [{"name": "...", "qualification": "..."}, {...}],
//   "reviewedAt": "2026-12-01"
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tahap pertama yang memuat hukum tajwid dan penilaian ulama; tahap di
/// bawahnya hanya literasi Arab dasar dan sudah terbit lebih dulu.
const _firstGatedLevel = 6;

List<Map<String, dynamic>> _lessons() {
  final root =
      jsonDecode(File('assets/learn/curriculum.json').readAsStringSync())
          as Map<String, dynamic>;
  return (root['lessons'] as List).cast<Map<String, dynamic>>();
}

void main() {
  test('tahap 6 ke atas tidak terbit tanpa dua peninjau tercatat', () {
    final violations = <String>[];
    for (final lesson in _lessons()) {
      final level = lesson['level'];
      final status = lesson['review'];
      if (level is! int || level < _firstGatedLevel) continue;
      if (status != 'published' && status != 'approved') continue;

      final reviewers = <String>{
        for (final r in (lesson['reviewers'] as List?) ?? const [])
          if (r is Map && (r['name'] as String?)?.trim().isNotEmpty == true)
            (r['name'] as String).trim(),
      };
      if (reviewers.length < 2) {
        violations.add(
          '${lesson['id']} berstatus $status tetapi hanya '
          '${reviewers.length} peninjau tercatat (perlu 2 nama berbeda).',
        );
      }
      final reviewedAt = lesson['reviewedAt'];
      if (reviewedAt is! String || reviewedAt.trim().isEmpty) {
        violations.add('${lesson['id']} berstatus $status tanpa "reviewedAt".');
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Aturan dua peninjau '
          '(docs/RELIGIOUS_CONTENT_GOVERNANCE.md) dilanggar:\n'
          '${violations.join('\n')}',
    );
  });

  test(
    'setiap audio contoh yang diisi menunjuk berkas yang ada dan terdaftar',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final violations = <String>[];
      for (final lesson in _lessons()) {
        for (final block
            in (lesson['blocks'] as List).cast<Map<String, dynamic>>()) {
          if (block['type'] != 'audio') continue;
          final asset = (block['asset'] as String?)?.trim();
          if (asset == null || asset.isEmpty) continue; // belum direkam: sah

          if (!File(asset).existsSync()) {
            violations.add('${lesson['id']}: berkas "$asset" tidak ada.');
            continue;
          }
          final dir = asset.substring(0, asset.lastIndexOf('/') + 1);
          if (!pubspec.contains('- $asset') && !pubspec.contains('- $dir')) {
            violations.add(
              '${lesson['id']}: "$asset" belum didaftarkan di pubspec.yaml '
              '(tambahkan "- $dir").',
            );
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
