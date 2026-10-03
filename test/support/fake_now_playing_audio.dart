import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Pemutar palsu untuk dock, baris "sedang diputar", dan layar Murottal.
class FakeNowPlayingAudio extends ChangeNotifier implements MurottalAudio {
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

  @override
  double speed = 1;
  @override
  DateTime? sleepAt;
  @override
  String? error;
  @override
  bool wholeSurah = false;

  /// Posisi & durasi ayat yang tetap, supaya golden stabil ("0:01 / 0:06").
  Duration positionValue = const Duration(milliseconds: 1400);
  Duration? durationValue = const Duration(seconds: 6);

  @override
  Stream<AyahProgress> get progress =>
      Stream.value((position: positionValue, duration: durationValue));

  final jumps = <int>[];
  int previouses = 0;
  final repeats = <AudioRepeat>[];
  final speeds = <double>[];
  final sleeps = <Duration?>[];
  final ranges =
      <
        ({
          int surah,
          int fromAyah,
          int toAyah,
          int? repeatCount,
          int? startAyah,
        })
      >[];
  final playedFrom = <(int, int)>[];

  /// Memindah ayat yang diputar dalam antrean, seperti pemutar sungguhan.
  void moveTo(int ayah) {
    playingVerse = '${queue!.surah}:$ayah';
    notifyListeners();
  }

  /// Meniru [QuranAudioService]: pesan galat diisi lalu pemutar ditutup.
  void fail(String message) {
    error = message;
    notifyListeners();
    error = null;
    queue = null;
    playingVerse = null;
    notifyListeners();
  }

  @override
  Future<void> previous() async => previouses++;

  @override
  Future<void> jumpTo(int index) async {
    jumps.add(index);
    moveTo(queue!.ayahAt(index));
  }

  @override
  Future<void> setRepeat(AudioRepeat mode) async {
    repeats.add(mode);
    repeat = mode;
    notifyListeners();
  }

  @override
  Future<void> playRange({
    required int surah,
    required int fromAyah,
    required int toAyah,
    int? repeatCount = 1,
    int? startAyah,
    Duration? position,
  }) async {
    ranges.add((
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
      repeatCount: repeatCount,
      startAyah: startAyah,
    ));
    queue = AudioQueue.from(surah, fromAyah, toAyah: toAyah);
    playingVerse = '$surah:${startAyah ?? fromAyah}';
    repeat = repeatCount == 1 ? AudioRepeat.off : AudioRepeat.range;
    rangeTarget = repeatCount == 1 ? 1 : repeatCount;
    notifyListeners();
  }

  @override
  Future<void> playFrom(int surah, int ayah) async {
    playedFrom.add((surah, ayah));
    play(surah, ayah);
  }

  @override
  Future<void> setSpeed(double value) async {
    speeds.add(value);
    speed = value;
    notifyListeners();
  }

  @override
  void setSleepTimer(Duration? after) {
    sleeps.add(after);
    sleepAt = after == null ? null : DateTime(2026, 10, 2, 10, 32).add(after);
    notifyListeners();
  }
}
