import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

enum AudioRepeat { off, verse, range }

/// Inclusive verse range of one surah loaded into the player as a playlist.
@immutable
class AudioQueue {
  const AudioQueue({
    required this.surah,
    required this.firstAyah,
    required this.lastAyah,
  });

  /// Playlist from [ayah] to [toAyah], or to the end of the surah.
  factory AudioQueue.from(int surah, int ayah, {int? toAyah}) {
    final count = surahCatalog[surah - 1].ayahCount;
    final last = toAyah ?? count;
    if (ayah < 1 || ayah > count) throw RangeError.range(ayah, 1, count);
    if (last < ayah || last > count) throw RangeError.range(last, ayah, count);
    return AudioQueue(surah: surah, firstAyah: ayah, lastAyah: last);
  }

  final int surah;
  final int firstAyah;
  final int lastAyah;

  int get length => lastAyah - firstAyah + 1;
  int ayahAt(int index) => firstAyah + index.clamp(0, length - 1);
  String keyAt(int index) => '$surah:${ayahAt(index)}';

  @override
  bool operator ==(Object other) =>
      other is AudioQueue &&
      other.surah == surah &&
      other.firstAyah == firstAyah &&
      other.lastAyah == lastAyah;

  @override
  int get hashCode => Object.hash(surah, firstAyah, lastAyah);
}

/// Single shared player for per-verse recitation.
///
/// Resource: Mishary Rashid Alafasy, 128 kbps, per-verse files from the
/// Islamic Network CDN (edition `ar.alafasy` on api.alquran.cloud), addressed
/// by global verse number. Streaming only; offline rights are not verified.
class QuranAudioService {
  QuranAudioService._() {
    _player.playerStateStream.listen(_syncState);
    _player.currentIndexStream.listen(_syncIndex);
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object _) {
        error.value = 'Murottal terputus. Periksa koneksi internet.';
        unawaited(stop());
      },
    );
  }
  static final instance = QuranAudioService._();
  static const reciterEdition = 'ar.alafasy';
  static const reciterName = 'Mishary Alafasy';
  static const _loadTimeout = Duration(seconds: 20);

  final _player = AudioPlayer();

  /// Loaded playlist; null when the player is closed.
  final queue = ValueNotifier<AudioQueue?>(null);

  /// Verse key (`surah:ayah`) the player is actually positioned on.
  final playingVerse = ValueNotifier<String?>(null);
  final isPlaying = ValueNotifier<bool>(false);
  final buffering = ValueNotifier<bool>(false);
  final repeat = ValueNotifier<AudioRepeat>(AudioRepeat.off);

  /// Last playback failure message, for the reader to surface once.
  final error = ValueNotifier<String?>(null);

  // Incremented on every new load so a slower, older load can never
  // overwrite the state of the verses the user picked afterwards.
  int _generation = 0;
  bool _loading = false;

  static Uri urlFor(int surah, int ayah) => Uri.https(
    'cdn.islamic.network',
    '/quran/audio/128/$reciterEdition/${globalAyahNumber(surah, ayah)}.mp3',
  );

  int? get _currentAyah {
    final q = queue.value;
    final index = _player.currentIndex;
    return q == null || index == null ? null : q.ayahAt(index);
  }

  void _syncIndex(int? index) {
    final q = queue.value;
    playingVerse.value = q == null || index == null ? null : q.keyAt(index);
  }

  void _syncState(PlayerState state) {
    isPlaying.value = state.playing;
    buffering.value =
        queue.value != null &&
        (_loading ||
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering);
    // Reaching the end of a non-looping playlist closes the player.
    if (!_loading && state.processingState == ProcessingState.completed) {
      unawaited(stop());
    }
  }

  /// Verse-card button: pause/resume the current verse, or start playing
  /// continuously from this verse to the end of the surah.
  Future<void> toggle({required int surah, required int ayah}) async {
    if (playingVerse.value == '$surah:$ayah') {
      return togglePlayPause();
    }
    await _load(AudioQueue.from(surah, ayah), AudioRepeat.off);
  }

  Future<void> playRange({
    required int surah,
    required int fromAyah,
    required int toAyah,
  }) => _load(
    AudioQueue.from(surah, fromAyah, toAyah: toAyah),
    AudioRepeat.range,
  );

  Future<void> togglePlayPause() async {
    if (queue.value == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  /// Moves back one verse, reloading from the previous verse when the
  /// playlist started mid-surah.
  Future<void> previous() async {
    final q = queue.value;
    final ayah = _currentAyah;
    if (q == null || ayah == null) return;
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (ayah > 1 && repeat.value != AudioRepeat.range) {
      await _load(AudioQueue.from(q.surah, ayah - 1), repeat.value);
    }
  }

  Future<void> setRepeat(AudioRepeat mode) async {
    final q = queue.value;
    final ayah = _currentAyah;
    if (q == null || ayah == null || mode == AudioRepeat.range) return;
    if (repeat.value == AudioRepeat.range) {
      // Leaving a range: continue from the same point to the end of surah.
      await _load(
        AudioQueue.from(q.surah, ayah),
        mode,
        position: _player.position,
      );
      return;
    }
    await _player.setLoopMode(
      mode == AudioRepeat.verse ? LoopMode.one : LoopMode.off,
    );
    repeat.value = mode;
  }

  Future<void> stop() async {
    ++_generation;
    _loading = false;
    queue.value = null;
    playingVerse.value = null;
    repeat.value = AudioRepeat.off;
    buffering.value = false;
    // Listeners have already shown any message; reset so a repeat of the
    // same failure still notifies.
    error.value = null;
    await _player.stop();
  }

  Future<void> _load(
    AudioQueue next,
    AudioRepeat mode, {
    Duration? position,
  }) async {
    final generation = ++_generation;
    _loading = true;
    error.value = null;
    queue.value = next;
    repeat.value = mode;
    playingVerse.value = next.keyAt(0);
    buffering.value = true;
    try {
      await _player.setLoopMode(switch (mode) {
        AudioRepeat.off => LoopMode.off,
        AudioRepeat.verse => LoopMode.one,
        AudioRepeat.range => LoopMode.all,
      });
      await _player
          .setAudioSources([
            for (var ayah = next.firstAyah; ayah <= next.lastAyah; ayah++)
              AudioSource.uri(urlFor(next.surah, ayah)),
          ], initialPosition: position)
          .timeout(_loadTimeout);
      if (generation != _generation) return;
      _loading = false;
      _syncIndex(_player.currentIndex);
      unawaited(_player.play());
    } catch (_) {
      // A newer request interrupted this load; its state is not ours to clear.
      if (generation != _generation) return;
      await stop();
      rethrow;
    }
  }
}
