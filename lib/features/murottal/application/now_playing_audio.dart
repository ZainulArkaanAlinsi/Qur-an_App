import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Yang dibutuhkan dock dan baris "sedang diputar" dari pemutar murottal.
///
/// Dipisah dari [QuranAudioService] supaya dock bisa dites tanpa pemutar
/// sungguhan (just_audio butuh platform). Produksi memakai
/// [QuranNowPlayingAudio].
abstract class NowPlayingAudio implements Listenable {
  AudioQueue? get queue;

  /// Kunci ayat yang diputar, "surah:ayat".
  String? get playingVerse;
  bool get isPlaying;
  bool get buffering;
  AudioRepeat get repeat;
  int get rangePass;
  int? get rangeTarget;
  String? get sourceNote;
  String get reciterName;

  /// Posisi di ayat yang diputar (0..1), dibatasi 10 Hz (DESIGN v6 §6).
  Stream<double> get verseFraction;

  Future<void> togglePlayPause();
  Future<void> next();
  Future<void> stop();

  /// Titik untuk "Urungkan" setelah [stop]; null bila tidak ada yang diputar.
  AudioResumePoint? resumePoint();

  /// Memuat lagi [point] dan memutar lagi bila tadinya sedang diputar.
  Future<void> restore(AudioResumePoint point);

  /// Nomor ayat dari [playingVerse], atau null.
  static int? ayahOf(String? key) {
    if (key == null) return null;
    return int.tryParse(key.split(':').last);
  }
}

/// Kontrol tambahan untuk layar Murottal (20-murottal.md §5), di atas yang
/// dibutuhkan dock.
abstract class MurottalAudio implements NowPlayingAudio {
  double get speed;

  /// Waktu pemutaran berhenti sendiri, atau null.
  DateTime? get sleepAt;

  /// Pesan kegagalan terakhir. [QuranAudioService] langsung menutup pemutar
  /// setelah mengisinya, jadi pendengar harus membacanya saat diberi tahu.
  String? get error;

  /// Diputar dari satu berkas per surah: posisi ayat tidak diketahui.
  bool get wholeSurah;

  /// Posisi & durasi ayat yang diputar, dibatasi 10 Hz (20-murottal.md §4).
  /// Tiap panggilan membuat stream baru: simpan di `State`, jangan dipanggil
  /// di `build`.
  Stream<AyahProgress> get progress;

  Future<void> previous();

  /// Lompat ke ayat ke-[index] (0-based) dalam antrean.
  Future<void> jumpTo(int index);
  Future<void> setRepeat(AudioRepeat mode);
  Future<void> playRange({
    required int surah,
    required int fromAyah,
    required int toAyah,
    int? repeatCount,
    int? startAyah,
    Duration? position,
  });

  /// Memutar [surah] dari [ayah] sampai akhir surah.
  Future<void> playFrom(int surah, int ayah);
  Future<void> setSpeed(double value);
  void setSleepTimer(Duration? after);
}

/// Posisi di ayat yang diputar.
typedef AyahProgress = ({Duration position, Duration? duration});

/// [NowPlayingAudio] di atas [QuranAudioService.instance].
class QuranNowPlayingAudio implements MurottalAudio {
  QuranNowPlayingAudio([QuranAudioService? service])
    : _audio = service ?? QuranAudioService.instance;

  final QuranAudioService _audio;

  late final Listenable _changes = Listenable.merge([
    _audio.queue,
    _audio.playingVerse,
    _audio.isPlaying,
    _audio.buffering,
    _audio.repeat,
    _audio.rangePass,
    _audio.rangeTarget,
    _audio.sourceNote,
    _audio.speed,
    _audio.sleepAt,
    _audio.error,
    _audio.wholeSurah,
  ]);

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  @override
  AudioQueue? get queue => _audio.queue.value;
  @override
  String? get playingVerse => _audio.playingVerse.value;
  @override
  bool get isPlaying => _audio.isPlaying.value;
  @override
  bool get buffering => _audio.buffering.value;
  @override
  AudioRepeat get repeat => _audio.repeat.value;
  @override
  int get rangePass => _audio.rangePass.value;
  @override
  int? get rangeTarget => _audio.rangeTarget.value;
  @override
  String? get sourceNote => _audio.sourceNote.value;
  @override
  String get reciterName => QuranAudioService.reciterName;

  @override
  Stream<double> get verseFraction async* {
    Duration? total;
    final durations = _audio.durationStream.listen((value) => total = value);
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final position in _audio.positionStream) {
        final now = DateTime.now();
        if (now.difference(last) < const Duration(milliseconds: 100)) continue;
        last = now;
        final length = total;
        yield length == null || length.inMilliseconds == 0
            ? 0
            : (position.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);
      }
    } finally {
      await durations.cancel();
    }
  }

  @override
  Future<void> togglePlayPause() => _audio.togglePlayPause();
  @override
  Future<void> next() => _audio.next();
  @override
  Future<void> stop() => _audio.stop();
  @override
  AudioResumePoint? resumePoint() => _audio.resumePoint();

  @override
  Future<void> restore(AudioResumePoint point) async {
    await _audio.restore(point);
    if (point.wasPlaying) await _audio.togglePlayPause(resume: true);
  }

  @override
  double get speed => _audio.speed.value;
  @override
  DateTime? get sleepAt => _audio.sleepAt.value;
  @override
  String? get error => _audio.error.value;
  @override
  bool get wholeSurah => _audio.wholeSurah.value;
  @override
  Stream<AyahProgress> get progress async* {
    Duration? total;
    final durations = _audio.durationStream.listen((value) => total = value);
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final position in _audio.positionStream) {
        final now = DateTime.now();
        if (now.difference(last) < const Duration(milliseconds: 100)) continue;
        last = now;
        yield (position: position, duration: total);
      }
    } finally {
      await durations.cancel();
    }
  }

  @override
  Future<void> previous() => _audio.previous();
  @override
  Future<void> jumpTo(int index) => _audio.jumpTo(index);
  @override
  Future<void> setRepeat(AudioRepeat mode) => _audio.setRepeat(mode);
  @override
  Future<void> playRange({
    required int surah,
    required int fromAyah,
    required int toAyah,
    int? repeatCount = 1,
    int? startAyah,
    Duration? position,
  }) => _audio.playRange(
    surah: surah,
    fromAyah: fromAyah,
    toAyah: toAyah,
    repeatCount: repeatCount,
    startAyah: startAyah,
    position: position,
  );
  @override
  Future<void> playFrom(int surah, int ayah) =>
      // toggle() menjeda bila ayat itu sedang dimuat; di sini selalu putar.
      _audio.playingVerse.value == '$surah:$ayah'
      ? _audio.togglePlayPause(resume: true)
      : _audio.toggle(surah: surah, ayah: ayah);
  @override
  Future<void> setSpeed(double value) => _audio.setSpeed(value);
  @override
  void setSleepTimer(Duration? after) => _audio.setSleepTimer(after);
}
