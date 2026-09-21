import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

/// Single shared player for per-verse recitation.
///
/// Resource: Mishary Rashid Alafasy, 128 kbps, per-verse files from the
/// Islamic Network CDN (edition `ar.alafasy` on api.alquran.cloud), addressed
/// by global verse number. Streaming only; offline rights are not verified.
class QuranAudioService {
  QuranAudioService._() {
    _player.playerStateStream.listen(_syncState);
    _player.playbackEventStream.listen((_) {}, onError: (Object _) => _clear());
  }
  static final instance = QuranAudioService._();
  static const reciterEdition = 'ar.alafasy';
  static const _loadTimeout = Duration(seconds: 20);

  final _player = AudioPlayer();

  /// Verse key (`surah:ayah`) that is loading or playing.
  final playingVerse = ValueNotifier<String?>(null);
  final repeatingVerse = ValueNotifier<String?>(null);

  /// True while [playingVerse] is loading or waiting for network data.
  final buffering = ValueNotifier<bool>(false);

  // Incremented on every new request so a slower, older load can never
  // overwrite the state of the verse the user picked afterwards.
  int _generation = 0;
  bool _loading = false;
  bool _wasPlaying = false;

  static Uri urlFor(int surah, int ayah) => Uri.https(
    'cdn.islamic.network',
    '/quran/audio/128/$reciterEdition/${globalAyahNumber(surah, ayah)}.mp3',
  );

  void _syncState(PlayerState state) {
    buffering.value =
        playingVerse.value != null &&
        (_loading ||
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering);
    final stoppedPlaying = _wasPlaying && !state.playing;
    _wasPlaying = state.playing;
    if (_loading) return;
    // Covers natural completion and pauses made by the system, such as an
    // incoming call or unplugged headphones, so the UI follows the player.
    // Only a playing → paused transition counts; a late `ready` event from
    // loading a fresh verse must not clear it before playback starts.
    if (state.processingState == ProcessingState.completed || stoppedPlaying) {
      _clear();
    }
  }

  void _clear() {
    playingVerse.value = null;
    repeatingVerse.value = null;
    buffering.value = false;
  }

  Future<void> toggle({required int surah, required int ayah}) async {
    final key = '$surah:$ayah';
    final generation = ++_generation;
    if (playingVerse.value == key) {
      _loading = false;
      await _player.pause();
      await _player.setLoopMode(LoopMode.off);
      _clear();
      return;
    }
    _loading = true;
    repeatingVerse.value = null;
    playingVerse.value = key;
    buffering.value = true;
    try {
      await _player.setLoopMode(LoopMode.off);
      await _player
          .setUrl(urlFor(surah, ayah).toString())
          .timeout(_loadTimeout);
      if (generation != _generation) return;
      _loading = false;
      unawaited(_player.play());
    } catch (_) {
      // A newer request interrupted this load; its state is not ours to clear.
      if (generation != _generation) return;
      _loading = false;
      await _player.stop();
      _clear();
      rethrow;
    }
  }

  Future<void> toggleRepeat({required int surah, required int ayah}) async {
    final key = '$surah:$ayah';
    if (repeatingVerse.value == key) {
      await _player.setLoopMode(LoopMode.off);
      repeatingVerse.value = null;
      return;
    }
    if (playingVerse.value != key) {
      await toggle(surah: surah, ayah: ayah);
    }
    if (playingVerse.value != key) return;
    await _player.setLoopMode(LoopMode.one);
    repeatingVerse.value = key;
  }
}
