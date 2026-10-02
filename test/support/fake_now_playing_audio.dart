import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Pemutar palsu untuk dock dan baris "sedang diputar" di tes.
class FakeNowPlayingAudio extends ChangeNotifier implements NowPlayingAudio {
  @override
  AudioQueue? queue;
  @override
  String? playingVerse;
  @override
  bool isPlaying = true;
  @override
  bool buffering = false;
  @override
  AudioRepeat repeat = AudioRepeat.off;
  @override
  int rangePass = 1;
  @override
  int? rangeTarget;
  @override
  String? sourceNote;
  @override
  String reciterName = 'Hudhaify';

  /// Posisi tetap di ayat yang diputar, supaya golden stabil.
  double fraction = .4;

  int stops = 0;
  int toggles = 0;
  int nexts = 0;
  AudioResumePoint? restored;

  @override
  Stream<double> get verseFraction => Stream.value(fraction);

  /// Memutar [surah] di [ayah], antrean sampai [toAyah] (bawaan akhir surah).
  void play(int surah, int ayah, {int? from, int? toAyah}) {
    queue = AudioQueue.from(surah, from ?? ayah, toAyah: toAyah);
    playingVerse = '$surah:$ayah';
    notifyListeners();
  }

  @override
  Future<void> togglePlayPause() async {
    toggles++;
    isPlaying = !isPlaying;
    notifyListeners();
  }

  @override
  Future<void> next() async => nexts++;

  @override
  Future<void> stop() async {
    stops++;
    queue = null;
    playingVerse = null;
    notifyListeners();
  }

  @override
  AudioResumePoint? resumePoint() {
    final q = queue;
    final ayah = NowPlayingAudio.ayahOf(playingVerse);
    if (q == null || ayah == null) return null;
    return AudioResumePoint(
      surah: q.surah,
      ayah: ayah,
      lastAyah: q.lastAyah,
      repeat: repeat,
      position: const Duration(seconds: 2),
      wasPlaying: isPlaying,
    );
  }

  @override
  Future<void> restore(AudioResumePoint point) async {
    restored = point;
    play(point.surah, point.ayah, toAyah: point.lastAyah);
  }
}
