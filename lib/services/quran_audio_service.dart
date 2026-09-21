import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';

class QuranAudioService {
  QuranAudioService._() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed)
        playingVerse.value = null;
    });
  }
  static final instance = QuranAudioService._();
  final _player = AudioPlayer();
  final playingVerse = ValueNotifier<String?>(null);

  Future<void> toggle({
    required int surah,
    required int ayah,
    required int globalAyah,
  }) async {
    final key = '$surah:$ayah';
    if (playingVerse.value == key) {
      await _player.pause();
      playingVerse.value = null;
      return;
    }
    playingVerse.value = key;
    try {
      await _player.setUrl(
        'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$globalAyah.mp3',
      );
      await _player.play();
    } catch (_) {
      playingVerse.value = null;
      rethrow;
    }
  }
}
