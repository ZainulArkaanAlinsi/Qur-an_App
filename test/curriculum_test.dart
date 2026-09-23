import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Satu pelajaran yang sah, untuk dirusak per bagian di tiap tes.
Map<String, dynamic> _lesson({
  String id = 'huruf',
  int level = 1,
  int order = 1,
  String review = 'draft',
  String provenance = 'Draf; belum diperiksa.',
  List<Map<String, dynamic>>? blocks,
  List<Map<String, dynamic>>? sources,
  String? rule,
}) => {
  'id': id,
  'level': level,
  'order': order,
  'title': 'Huruf hijaiyah',
  'summary': 'Dua puluh delapan huruf.',
  'objectives': ['Menyebut nama huruf'],
  'review': review,
  'provenance': provenance,
  'sources': sources ?? [],
  if (rule != null) 'rule': rule,
  'blocks': blocks ?? [],
};

String _doc(List<Map<String, dynamic>> lessons) =>
    jsonEncode({'version': 1, 'lessons': lessons});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('aset kurikulum yang dibundel', () {
    test('terbaca dan seluruhnya masih draf', () async {
      final raw = await rootBundle.loadString(CurriculumRepository.asset);
      final curriculum = CurriculumRepository.parse(raw);

      expect(curriculum.lessons, hasLength(17));
      expect(
        curriculum.lessons.map((lesson) => lesson.level),
        List.generate(17, (index) => index),
        reason: 'tahap 0 sampai 16 lengkap dan berurutan',
      );

      // Aturan repo: hanya materi terbit yang boleh tampil di rilis. Selama
      // belum ada peninjau, tidak boleh ada satu pun yang berstatus terbit.
      expect(
        curriculum.visible(includeDrafts: false),
        isEmpty,
        reason: 'materi agama tanpa peninjau tidak boleh tampil di rilis',
      );
      expect(curriculum.visible(includeDrafts: true), hasLength(17));
    });

    test('setiap pelajaran menyebut asal materinya', () async {
      final raw = await rootBundle.loadString(CurriculumRepository.asset);
      for (final lesson in CurriculumRepository.parse(raw).lessons) {
        expect(
          lesson.provenance.trim(),
          isNotEmpty,
          reason: 'pelajaran "${lesson.id}" tidak menyebut asal materinya',
        );
      }
    });

    test('tidak ada blok audio yang mengaku punya rekaman', () async {
      final raw = await rootBundle.loadString(CurriculumRepository.asset);
      for (final lesson in CurriculumRepository.parse(raw).lessons) {
        for (final block in lesson.blocks) {
          if (block is LessonAudio) {
            // Rekaman wajib suara manusia berizin; belum ada satu pun.
            expect(
              block.isReady,
              isFalse,
              reason: 'audio "${block.label}" mengaku siap padahal belum ada',
            );
          }
        }
      }
    });
  });

  group('parser', () {
    test('mengurutkan berdasarkan level lalu order', () {
      final curriculum = CurriculumRepository.parse(
        _doc([
          _lesson(id: 'c', level: 3),
          _lesson(id: 'b', level: 1, order: 2),
          _lesson(id: 'a', level: 1),
        ]),
      );
      expect(curriculum.lessons.map((lesson) => lesson.id), ['a', 'b', 'c']);
    });

    test('id kembar ditolak', () {
      expect(
        () => CurriculumRepository.parse(
          _doc([_lesson(id: 'x'), _lesson(id: 'x', level: 2)]),
        ),
        throwsFormatException,
      );
    });

    test('pelajaran tanpa keterangan asal ditolak', () {
      expect(
        () => CurriculumRepository.parse(_doc([_lesson(provenance: '')])),
        throwsFormatException,
      );
    });

    test('pelajaran terbit tanpa rujukan ditolak', () {
      expect(
        () => CurriculumRepository.parse(_doc([_lesson(review: 'published')])),
        throwsFormatException,
      );
      // Dengan rujukan, barulah boleh terbit.
      final ok = CurriculumRepository.parse(
        _doc([
          _lesson(
            review: 'published',
            sources: [
              {'title': 'Matan Tuhfatul Athfal', 'author': 'Al-Jamzuri'},
            ],
          ),
        ]),
      );
      expect(ok.lessons.single.isPublished, isTrue);
    });

    test('status review yang tidak dikenal ditolak', () {
      expect(
        () => CurriculumRepository.parse(_doc([_lesson(review: 'hampir')])),
        throwsFormatException,
      );
    });

    test('hukum tajwid yang tidak dikenal ditolak', () {
      expect(
        () => CurriculumRepository.parse(_doc([_lesson(rule: 'qalqalah')])),
        throwsFormatException,
        reason: 'ejaan provider adalah "qalaqah"',
      );
      final ok = CurriculumRepository.parse(_doc([_lesson(rule: 'qalaqah')]));
      expect(ok.lessons.single.rule, TajweedRule.qalqalah);
    });

    test('contoh ayat di luar jangkauan ditolak', () {
      for (final example in [
        {'type': 'example', 'surah': 115, 'ayah': 1},
        {'type': 'example', 'surah': 1, 'ayah': 8},
        {'type': 'example', 'surah': 1, 'ayah': 0},
      ]) {
        expect(
          () => CurriculumRepository.parse(
            _doc([
              _lesson(blocks: [example]),
            ]),
          ),
          throwsFormatException,
          reason: '$example',
        );
      }
    });

    test('soal dengan kunci di luar pilihan ditolak', () {
      expect(
        () => CurriculumRepository.parse(
          _doc([
            _lesson(
              blocks: [
                {
                  'type': 'quiz',
                  'question': 'Mana?',
                  'options': ['a', 'b'],
                  'answer': 2,
                },
              ],
            ),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('soal dengan satu pilihan ditolak', () {
      expect(
        () => CurriculumRepository.parse(
          _doc([
            _lesson(
              blocks: [
                {
                  'type': 'quiz',
                  'question': 'Mana?',
                  'options': ['a'],
                  'answer': 0,
                },
              ],
            ),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('jenis blok yang tidak dikenal ditolak', () {
      expect(
        () => CurriculumRepository.parse(
          _doc([
            _lesson(
              blocks: [
                {'type': 'video', 'url': 'x'},
              ],
            ),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('blok audio tanpa berkas dibaca sebagai belum siap', () {
      final curriculum = CurriculumRepository.parse(
        _doc([
          _lesson(
            blocks: [
              {'type': 'audio', 'label': 'Bunyi huruf', 'asset': null},
            ],
          ),
        ]),
      );
      final audio = curriculum.lessons.single.blocks.single as LessonAudio;
      expect(audio.isReady, isFalse);
      expect(audio.label, 'Bunyi huruf');
    });
  });

  group('kemajuan belajar', () {
    final curriculum = CurriculumRepository.parse(
      _doc([
        _lesson(id: 'a', level: 1),
        _lesson(id: 'b', level: 2),
        _lesson(id: 'c', level: 3),
      ]),
    );

    test('pelajaran berikutnya adalah yang pertama belum selesai', () {
      expect(curriculum.nextAfter({'a'}, includeDrafts: true)?.id, 'b');
      expect(
        curriculum.nextAfter({'a', 'b', 'c'}, includeDrafts: true),
        isNull,
      );
    });

    test('menghitung yang sudah selesai', () {
      expect(curriculum.completedCount({'a', 'c'}, includeDrafts: true), 2);
      // Id yang sudah tidak ada di kurikulum tidak ikut terhitung.
      expect(curriculum.completedCount({'a', 'lama'}, includeDrafts: true), 1);
    });

    test('di rilis tidak ada yang bisa diselesaikan selama semuanya draf', () {
      expect(curriculum.nextAfter({}, includeDrafts: false), isNull);
      expect(curriculum.completedCount({'a'}, includeDrafts: false), 0);
    });
  });
}
