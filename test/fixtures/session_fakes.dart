import 'dart:async';
import 'dart:io';

import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/session/presentation/session_audio.dart';

/// Teks Tanzil asli dari repo, per surah.
VerseTexts loadTanzilTexts() {
  final lines = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
      .readAsLinesSync()
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  var cursor = 0;
  return {
    for (final meta in surahCatalog)
      meta.number: lines.sublist(cursor, cursor += meta.ayahCount),
  };
}

/// Kurikulum asli dari repo.
Curriculum loadCurriculum() => CurriculumRepository.parse(
  File('assets/learn/curriculum.json').readAsStringSync(),
);

/// Qari palsu: tidak memutar apa pun. [offline] membuat pemutaran gagal
/// seperti HP tanpa internet dan audio belum terunduh.
class FakeSessionAudio implements SessionAudio {
  bool offline = false;
  int played = 0;
  int borrowed = 0;
  int returned = 0;

  @override
  Future<bool> hasOffline(int surah, int ayah) async => false;

  @override
  Future<void> playQari(
    int surah,
    int ayah, {
    int times = 1,
    double speed = 1,
  }) async {
    if (offline) throw const SocketException('offline');
    played++;
  }

  @override
  Future<void> stopQari() async {}

  @override
  Future<void> borrow() async => borrowed++;

  @override
  Future<void> giveBack() async => returned++;
}

/// Perekam palsu: menulis berkas kecil ke path yang diminta.
class FakeSessionRecorder implements SessionRecorder {
  bool allow = true;
  String? path;
  int plays = 0;
  int permissionAsked = 0;

  @override
  Future<bool> hasPermission() async {
    permissionAsked++;
    return allow;
  }

  @override
  Future<void> start(String path) async {
    this.path = path;
    File(path).writeAsBytesSync(const [0, 1, 2]);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Stream<double> amplitude() =>
      Stream.fromIterable(const [.1, .5, .8, .4, .6, .3, .7, .2]);

  @override
  Future<void> play(String path) async => plays++;

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> dispose() async {}
}
