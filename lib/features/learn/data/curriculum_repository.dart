import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Memuat jalur belajar dari `assets/learn/curriculum.json`.
///
/// Gagal tertutup, sama seperti materi tajwid: satu entri rusak menolak seluruh
/// berkas, bukan menampilkan separuh materi. Isi berkasnya ditulis dan
/// ditinjau manusia, bukan dihasilkan aplikasi saat berjalan.
class CurriculumRepository {
  static const asset = 'assets/learn/curriculum.json';

  static Future<Curriculum> load() async =>
      parse(await rootBundle.loadString(asset));

  static Curriculum parse(String raw) {
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Kurikulum harus berupa objek JSON.');
    }
    final list = root['lessons'];
    if (list is! List) {
      throw const FormatException('Bagian "lessons" harus berupa daftar.');
    }

    final seen = <String>{};
    final lessons = <Lesson>[];
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Entri pelajaran harus berupa objek.');
      }
      final id = _string(entry['id']);
      if (id.isEmpty) {
        throw const FormatException('Pelajaran tanpa "id".');
      }
      if (!seen.add(id)) {
        throw FormatException('Pelajaran "$id" ditulis lebih dari sekali.');
      }
      final level = entry['level'];
      final order = entry['order'];
      if (level is! int || level < 0) {
        throw FormatException('"level" pada "$id" tidak valid.');
      }
      if (order is! int || order < 1) {
        throw FormatException('"order" pada "$id" tidak valid.');
      }
      final title = _string(entry['title']);
      final summary = _string(entry['summary']);
      if (title.isEmpty || summary.isEmpty) {
        throw FormatException('Pelajaran "$id" belum punya judul/ringkasan.');
      }
      final review = _review(entry['review'], id);
      final provenance = _string(entry['provenance']);
      if (provenance.isEmpty) {
        // Tanpa keterangan asal, materi agama tidak boleh ditampilkan sama
        // sekali — bahkan sebagai draf berlabel.
        throw FormatException('Pelajaran "$id" tidak menyebut asal materinya.');
      }
      // Materi terbit wajib menyebutkan rujukannya; draf boleh belum.
      final sources = _sources(entry['sources'], id);
      if (review == ContentReviewStatus.published && sources.isEmpty) {
        throw FormatException('Pelajaran terbit "$id" tanpa rujukan.');
      }

      TajweedRule? rule;
      final ruleId = _string(entry['rule']);
      if (ruleId.isNotEmpty) {
        rule = TajweedRule.fromProviderClass(ruleId);
        if (rule == null) {
          throw FormatException('Hukum tajwid tidak dikenal: "$ruleId".');
        }
      }

      lessons.add(
        Lesson(
          id: id,
          level: level,
          order: order,
          title: title,
          summary: summary,
          objectives: _strings(entry['objectives'], id, 'objectives'),
          blocks: _blocks(entry['blocks'], id),
          sources: sources,
          review: review,
          provenance: provenance,
          rule: rule,
        ),
      );
    }

    lessons.sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.order.compareTo(b.order);
    });
    return Curriculum(lessons: lessons);
  }

  static ContentReviewStatus _review(Object? value, String id) {
    final name = _string(value);
    for (final status in ContentReviewStatus.values) {
      if (status.name == name) return status;
    }
    throw FormatException('Status review "$name" pada "$id" tidak dikenal.');
  }

  static List<String> _strings(Object? value, String id, String field) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"$field" pada "$id" harus berupa daftar.');
    }
    return [
      for (final item in value)
        if (_string(item).isNotEmpty) _string(item),
    ];
  }

  static List<LessonSource> _sources(Object? value, String id) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"sources" pada "$id" harus berupa daftar.');
    }
    final sources = <LessonSource>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Rujukan pada "$id" harus berupa objek.');
      }
      final title = _string(item['title']);
      if (title.isEmpty) {
        throw FormatException('Rujukan pada "$id" tanpa judul.');
      }
      sources.add(
        LessonSource(
          title: title,
          author: _string(item['author']),
          url: _string(item['url']),
        ),
      );
    }
    return sources;
  }

  static List<LessonBlock> _blocks(Object? value, String id) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('"blocks" pada "$id" harus berupa daftar.');
    }
    final blocks = <LessonBlock>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Blok pada "$id" harus berupa objek.');
      }
      blocks.add(_block(item, id));
    }
    return blocks;
  }

  static LessonBlock _block(Map<String, dynamic> item, String id) {
    final type = _string(item['type']);
    switch (type) {
      case 'text':
      case 'tip':
        final text = _string(item['text']);
        if (text.isEmpty) {
          throw FormatException('Blok "$type" pada "$id" kosong.');
        }
        return type == 'text' ? LessonText(text) : LessonTip(text);

      case 'example':
        final surah = item['surah'];
        final ayah = item['ayah'];
        if (surah is! int || surah < 1 || surah > surahCatalog.length) {
          throw FormatException('Nomor surah contoh pada "$id" tidak valid.');
        }
        if (ayah is! int ||
            ayah < 1 ||
            ayah > surahCatalog[surah - 1].ayahCount) {
          throw FormatException('Nomor ayat contoh pada "$id" tidak valid.');
        }
        return LessonExample(
          surah: surah,
          ayah: ayah,
          note: _string(item['note']),
        );

      case 'audio':
        final label = _string(item['label']);
        if (label.isEmpty) {
          throw FormatException('Blok audio pada "$id" tanpa label.');
        }
        final assetPath = _string(item['asset']);
        return LessonAudio(
          label: label,
          asset: assetPath.isEmpty ? null : assetPath,
        );

      case 'quiz':
        final quizId = _string(item['id']);
        final question = _string(item['question']);
        final options = _strings(item['options'], id, 'options');
        final answer = item['answer'];
        if (quizId.isEmpty) {
          // Tanpa id tetap, riwayat jawaban akan menunjuk soal yang keliru
          // begitu urutannya digeser.
          throw FormatException('Soal pada "$id" tanpa "id".');
        }
        if (question.isEmpty) {
          throw FormatException('Soal pada "$id" tanpa pertanyaan.');
        }
        if (options.length < 2) {
          throw FormatException('Soal pada "$id" perlu minimal dua pilihan.');
        }
        if (answer is! int || answer < 0 || answer >= options.length) {
          throw FormatException('Kunci jawaban pada "$id" di luar pilihan.');
        }
        return LessonQuiz(
          id: quizId,
          question: question,
          options: options,
          answer: answer,
          explanation: _string(item['explanation']),
        );

      default:
        throw FormatException('Jenis blok "$type" pada "$id" tidak dikenal.');
    }
  }

  static String _string(Object? value) => value is String ? value.trim() : '';
}
