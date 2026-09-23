import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Sumber materi tajwid. Tanpa judul sumber dan nama peninjau, materinya tidak
/// ditampilkan: aturan agama harus jelas asalnya dan sudah diperiksa orang yang
/// berkompeten (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
@immutable
class TajweedSource {
  const TajweedSource({
    required this.title,
    required this.author,
    required this.url,
    required this.reviewedBy,
    required this.reviewedOn,
  });

  final String title;
  final String author;
  final String url;
  final String reviewedBy;
  final String reviewedOn;

  bool get isComplete =>
      title.trim().isNotEmpty && reviewedBy.trim().isNotEmpty;
}

/// Contoh ayat untuk satu hukum. Hanya rujukannya yang disimpan; teks Arabnya
/// diambil dari dataset Tanzil supaya tidak ada ayat yang diketik ulang.
@immutable
class TajweedExample {
  const TajweedExample({
    required this.surah,
    required this.ayah,
    required this.note,
  });

  final int surah;
  final int ayah;

  /// Keterangan singkat dari penyusun materi, mis. bagian mana yang dimaksud.
  final String note;
}

@immutable
class TajweedLesson {
  const TajweedLesson({
    required this.rule,
    required this.title,
    required this.summary,
    required this.detail,
    required this.examples,
  });

  final TajweedRule rule;
  final String title;
  final String summary;
  final String detail;
  final List<TajweedExample> examples;
}

@immutable
class TajweedLessonBook {
  const TajweedLessonBook({required this.source, required this.lessons});

  final TajweedSource source;
  final List<TajweedLesson> lessons;

  /// Materi baru dianggap siap tampil bila sumbernya lengkap dan ada isinya.
  bool get isReady => lessons.isNotEmpty && source.isComplete;
}

/// Memuat materi tajwid dari `assets/learn/tajweed_lessons.json`.
///
/// Gagal tertutup: entri yang rusak ditolak seluruhnya, bukan ditampilkan
/// separuh. Isi berkasnya ditulis manusia, bukan dihasilkan aplikasi.
class TajweedLessonRepository {
  static const asset = 'assets/learn/tajweed_lessons.json';

  static Future<TajweedLessonBook> load() async =>
      parse(await rootBundle.loadString(asset));

  static TajweedLessonBook parse(String raw) {
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Materi tajwid harus berupa objek JSON.');
    }
    final sourceJson = root['source'];
    if (sourceJson is! Map<String, dynamic>) {
      throw const FormatException('Bagian "source" tidak ada.');
    }
    final source = TajweedSource(
      title: _string(sourceJson['title']),
      author: _string(sourceJson['author']),
      url: _string(sourceJson['url']),
      reviewedBy: _string(sourceJson['reviewedBy']),
      reviewedOn: _string(sourceJson['reviewedOn']),
    );

    final lessonsJson = root['lessons'];
    if (lessonsJson is! List) {
      throw const FormatException('Bagian "lessons" harus berupa daftar.');
    }

    final seen = <TajweedRule>{};
    final lessons = <TajweedLesson>[];
    for (final entry in lessonsJson) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Entri materi harus berupa objek.');
      }
      final ruleId = _string(entry['rule']);
      final rule = TajweedRule.fromProviderClass(ruleId);
      if (rule == null) {
        throw FormatException('Hukum tajwid tidak dikenal: "$ruleId".');
      }
      if (!seen.add(rule)) {
        throw FormatException('Hukum "$ruleId" ditulis lebih dari sekali.');
      }
      final title = _string(entry['title']);
      final summary = _string(entry['summary']);
      final detail = _string(entry['detail']);
      if (title.isEmpty || summary.isEmpty || detail.isEmpty) {
        throw FormatException('Materi "$ruleId" belum lengkap.');
      }
      lessons.add(
        TajweedLesson(
          rule: rule,
          title: title,
          summary: summary,
          detail: detail,
          examples: _examples(entry['examples'], ruleId),
        ),
      );
    }
    return TajweedLessonBook(source: source, lessons: lessons);
  }

  static List<TajweedExample> _examples(Object? value, String ruleId) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"examples" pada "$ruleId" harus daftar.');
    }
    return [
      for (final item in value)
        () {
          if (item is! Map<String, dynamic>) {
            throw FormatException('Contoh pada "$ruleId" harus objek.');
          }
          final surah = item['surah'];
          final ayah = item['ayah'];
          if (surah is! int || surah < 1 || surah > surahCatalog.length) {
            throw FormatException('Nomor surah contoh "$ruleId" tidak valid.');
          }
          if (ayah is! int ||
              ayah < 1 ||
              ayah > surahCatalog[surah - 1].ayahCount) {
            throw FormatException('Nomor ayat contoh "$ruleId" tidak valid.');
          }
          return TajweedExample(
            surah: surah,
            ayah: ayah,
            note: _string(item['note']),
          );
        }(),
    ];
  }

  static String _string(Object? value) => value is String ? value.trim() : '';
}
