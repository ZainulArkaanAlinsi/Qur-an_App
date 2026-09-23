import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

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

/// Cara sebuah rentang diputar sebanyak N kali.
///
/// Dipisahkan dari [QuranAudioService] supaya aturannya bisa diuji tanpa
/// pemutar sungguhan — di sinilah dulu bug 3×/5×/10× bersarang.
@immutable
class RangePlan {
  const RangePlan({
    required this.mode,
    required this.copies,
    required this.passTarget,
  });

  /// Rencana untuk rentang sepanjang [length] ayat yang diminta diulang
  /// [repeatCount] kali; `null` berarti tanpa batas.
  factory RangePlan.of({required int length, required int? repeatCount}) {
    if (repeatCount == null) {
      // Tanpa batas: satu salinan rentang, diulang terus oleh pemutar.
      return const RangePlan(
        mode: AudioRepeat.range,
        copies: 1,
        passTarget: null,
      );
    }
    final passes = repeatCount < 1 ? 1 : repeatCount;
    if (passes == 1) {
      // Sekali jalan: daftar dibatasi rentangnya, tanpa pengulangan sama
      // sekali, sehingga berhenti di ayat terakhir rentang — bukan di akhir
      // surah seperti perilaku lama.
      return const RangePlan(
        mode: AudioRepeat.off,
        copies: 1,
        passTarget: 1,
      );
    }
    if (length == 1) {
      // Rentang satu ayat tidak pernah berpindah indeks, jadi putarannya tidak
      // bisa dihitung dari perpindahan; daftarnya digandakan saja.
      return RangePlan(
        mode: AudioRepeat.off,
        copies: passes,
        passTarget: passes,
      );
    }
    return RangePlan(
      mode: AudioRepeat.range,
      copies: 1,
      passTarget: passes,
    );
  }

  final AudioRepeat mode;

  /// Berapa kali daftar ayat disalin berurutan.
  final int copies;

  /// Jumlah putaran yang diminta; `null` berarti tanpa batas.
  final int? passTarget;

  /// Jumlah berkas audio yang akan dimuat.
  int items(int length) => length * copies;

  @override
  bool operator ==(Object other) =>
      other is RangePlan &&
      other.mode == mode &&
      other.copies == copies &&
      other.passTarget == passTarget;

  @override
  int get hashCode => Object.hash(mode, copies, passTarget);

  @override
  String toString() =>
      'RangePlan(mode: $mode, copies: $copies, passTarget: $passTarget)';
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

  /// Qari bawaan bila pengguna belum memilih; lihat [SharedPreferencesService.getReciter].
  static const reciterEdition = 'ar.alafasy';

  /// Nama qari yang sedang dipakai, untuk mini-player dan notifikasi media.
  /// Sebelumnya tetap "Mishary Alafasy" walau qari lain dipilih.
  static String get reciterName =>
      SharedPreferencesService.getReciter().displayName;
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

  /// Kecepatan pemutaran yang sedang dipakai.
  final speed = ValueNotifier<double>(1);

  /// Waktu pemutaran akan berhenti sendiri, atau null bila tidak disetel.
  final sleepAt = ValueNotifier<DateTime?>(null);
  Timer? _sleepTimer;

  /// Putaran rentang yang sedang berjalan, mulai dari 1.
  final rangePass = ValueNotifier<int>(1);

  /// Jumlah putaran yang diminta, atau null bila tanpa batas.
  final rangeTarget = ValueNotifier<int?>(null);

  /// Indeks terakhir yang dilaporkan player, untuk mengenali putaran baru.
  int _lastIndex = 0;

  /// Posisi dan durasi ayat yang sedang diputar, untuk bar kemajuan.
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // Incremented on every new load so a slower, older load can never
  // overwrite the state of the verses the user picked afterwards.
  int _generation = 0;
  bool _loading = false;

  /// Registers notification, lock-screen and headset controls and keeps
  /// playback alive with the screen off. Failure leaves in-app playback
  /// working, so it never blocks app start-up.
  Future<void> initSystemControls() async {
    try {
      await AudioService.init(
        builder: () => _SystemControls(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'quran_app.murottal',
          androidNotificationChannelName: 'Murottal',
          androidNotificationIcon: 'drawable/ic_stat_quran',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
        // Runs before the first frame; never let it block app start.
      ).timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Kontrol murottal sistem tidak aktif: $error');
    }
  }

  // play() completes only when playback stops, and completes with an error
  // if a later playlist item fails to load. That failure already reaches the
  // UI through playbackEventStream, so it is consumed here instead of
  // surfacing as an uncaught asynchronous error.
  void _play() => unawaited(
    _player.play().catchError(
      (Object error) => debugPrint('Murottal gagal diputar: $error'),
    ),
  );

  /// URL ayat pada qari pilihan. Bitrate berbeda antar qari, jadi memakai
  /// nilai yang sudah diperiksa saat qari dipilih.
  static Uri urlFor(int surah, int ayah, {Reciter? reciter}) {
    final selected = reciter ?? SharedPreferencesService.getReciter();
    final bitrate = selected.bitrate ?? 128;
    return Uri.https(
      'cdn.islamic.network',
      '/quran/audio/$bitrate/${selected.identifier}/'
          '${globalAyahNumber(surah, ayah)}.mp3',
    );
  }

  /// Berkas lokal bila tersedia, kalau tidak URL CDN.
  static Uri sourceFor(
    int surah,
    int ayah, {
    required Reciter reciter,
    required String? folder,
  }) {
    if (folder != null) {
      final file = File('$folder/${globalAyahNumber(surah, ayah)}.mp3');
      if (file.existsSync() && file.lengthSync() > 0) return file.uri;
    }
    return urlFor(surah, ayah, reciter: reciter);
  }

  int? get _currentAyah {
    final q = queue.value;
    final index = _player.currentIndex;
    return q == null || index == null ? null : q.ayahAt(index);
  }

  void _syncIndex(int? index) {
    final q = queue.value;
    playingVerse.value = q == null || index == null ? null : q.keyAt(index);
    if (q == null || index == null) return;

    final target = rangeTarget.value;
    if (repeat.value == AudioRepeat.range && target != null && q.length > 1) {
      // Kembali ke awal rentang berarti satu putaran selesai.
      if (index == 0 && _lastIndex == q.length - 1) {
        rangePass.value = rangePass.value + 1;
      }
      // Pada ayat terakhir putaran pamungkas, pengulangan dimatikan supaya
      // daftar berakhir sendiri alih-alih terpotong di tengah ayat pertama.
      if (rangePass.value >= target && index == q.length - 1) {
        unawaited(_player.setLoopMode(LoopMode.off));
      }
    }
    _lastIndex = index;
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

  /// Memutar [fromAyah]–[toAyah] sebanyak [repeatCount] putaran; null berarti
  /// tanpa batas.
  ///
  /// Sebelumnya berapa pun angkanya selalu dipetakan ke `LoopMode.all`,
  /// sehingga 3×, 5×, dan 10× sama-sama tidak pernah berhenti. Sekarang
  /// jumlahnya benar-benar dihitung, dan satu putaran memutar rentangnya saja
  /// — bukan sampai akhir surah.
  Future<void> playRange({
    required int surah,
    required int fromAyah,
    required int toAyah,
    int? repeatCount = 1,
  }) {
    final next = AudioQueue.from(surah, fromAyah, toAyah: toAyah);
    final plan = RangePlan.of(length: next.length, repeatCount: repeatCount);
    return _load(
      next,
      plan.mode,
      copies: plan.copies,
      passTarget: plan.passTarget,
    );
  }

  /// Toggles playback, or forces a direction when [resume] is given, as
  /// media buttons do.
  Future<void> togglePlayPause({bool? resume}) async {
    if (queue.value == null) return;
    if (resume ?? !_player.playing) {
      _play();
    } else {
      await _player.pause();
    }
  }

  // Indices are computed here rather than via hasNext/seekToNext: under
  // LoopMode.one just_audio reports the *current* item as next/previous, so
  // skipping would only restart the verse being repeated.

  /// Moves to the next verse; wraps within a repeated range.
  Future<void> next() async {
    final q = queue.value;
    final index = _player.currentIndex;
    if (q == null || index == null || _loading) return;
    if (index + 1 < q.length) {
      await _player.seek(Duration.zero, index: index + 1);
    } else if (repeat.value == AudioRepeat.range) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  /// Moves back one verse, wrapping within a repeated range and reloading
  /// from the previous verse when the playlist started mid-surah.
  Future<void> previous() async {
    final q = queue.value;
    final index = _player.currentIndex;
    if (q == null || index == null || _loading) return;
    final ayah = q.ayahAt(index);
    if (index > 0) {
      await _player.seek(Duration.zero, index: index - 1);
    } else if (repeat.value == AudioRepeat.range) {
      await _player.seek(Duration.zero, index: q.length - 1);
    } else if (ayah > 1) {
      await _load(AudioQueue.from(q.surah, ayah - 1), repeat.value);
    }
  }

  /// Switches between continuous and single-verse repeat. Ignored while a
  /// playlist is loading (the menu is disabled then) so the change cannot
  /// race the load's own loop-mode setup.
  Future<void> setRepeat(AudioRepeat mode) async {
    final q = queue.value;
    final ayah = _currentAyah;
    if (q == null || ayah == null || mode == AudioRepeat.range || _loading) {
      return;
    }
    final generation = _generation;
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
    if (generation != _generation) return;
    repeat.value = mode;
  }

  /// Kecepatan dibatasi pada rentang yang masih terdengar jelas.
  Future<void> setSpeed(double value) async {
    final next = value.clamp(0.75, 1.5).toDouble();
    await _player.setSpeed(next);
    speed.value = next;
  }

  /// Menghentikan pemutaran setelah [after]; null membatalkan timer.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    if (after == null) {
      _sleepTimer = null;
      sleepAt.value = null;
      return;
    }
    sleepAt.value = DateTime.now().add(after);
    _sleepTimer = Timer(after, () => unawaited(stop()));
  }

  Future<void> stop() async {
    ++_generation;
    _loading = false;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepAt.value = null;
    queue.value = null;
    playingVerse.value = null;
    repeat.value = AudioRepeat.off;
    rangePass.value = 1;
    rangeTarget.value = null;
    _lastIndex = 0;
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
    int? passTarget,
    int copies = 1,
  }) async {
    final generation = ++_generation;
    _loading = true;
    error.value = null;
    queue.value = next;
    repeat.value = mode;
    playingVerse.value = next.keyAt(0);
    buffering.value = true;
    rangePass.value = 1;
    rangeTarget.value = passTarget ?? (copies > 1 ? copies : null);
    _lastIndex = 0;
    try {
      await _player.setLoopMode(switch (mode) {
        AudioRepeat.off => LoopMode.off,
        AudioRepeat.verse => LoopMode.one,
        AudioRepeat.range => LoopMode.all,
      });
      // Berkas yang sudah diunduh dipakai lebih dulu agar bisa diputar tanpa
      // internet; sisanya tetap di-stream.
      final reciter = SharedPreferencesService.getReciter();
      final folder = await AudioDownloadService().folderPath(reciter);
      await _player
          .setAudioSources([
            for (var copy = 0; copy < copies; copy++)
              for (var ayah = next.firstAyah; ayah <= next.lastAyah; ayah++)
                AudioSource.uri(
                  sourceFor(next.surah, ayah, reciter: reciter, folder: folder),
                ),
          ], initialPosition: position)
          .timeout(_loadTimeout);
      if (generation != _generation) return;
      _loading = false;
      _syncIndex(_player.currentIndex);
      _play();
    } catch (_) {
      // A newer request interrupted this load; its state is not ours to clear.
      if (generation != _generation) return;
      await stop();
      rethrow;
    }
  }
}

/// Mirrors [QuranAudioService] into the OS media session and routes its
/// buttons back, so the service stays the single source of truth.
class _SystemControls extends BaseAudioHandler {
  _SystemControls(this._audio) {
    final player = _audio._player;
    player.playbackEventStream.listen(
      (event) => playbackState.add(_state(event.currentIndex)),
      onError: (Object _) => playbackState.add(_state(null)),
    );
    player.playingStream.listen(
      (_) => playbackState.add(_state(player.currentIndex)),
    );
    _audio.playingVerse.addListener(_publishVerse);
  }

  final QuranAudioService _audio;

  void _publishVerse() {
    final key = _audio.playingVerse.value;
    if (key == null) return;
    final parts = key.split(':');
    final surah = surahCatalog[int.parse(parts.first) - 1];
    mediaItem.add(
      MediaItem(
        id: key,
        title: '${surah.displayName} · Ayat ${parts.last}',
        artist: QuranAudioService.reciterName,
        album: 'Murottal Al-Qur’an',
      ),
    );
  }

  PlaybackState _state(int? index) {
    final player = _audio._player;
    final active = _audio.queue.value != null;
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: !active
          ? AudioProcessingState.idle
          : switch (player.processingState) {
              ProcessingState.idle => AudioProcessingState.idle,
              ProcessingState.loading => AudioProcessingState.loading,
              ProcessingState.buffering => AudioProcessingState.buffering,
              ProcessingState.ready => AudioProcessingState.ready,
              ProcessingState.completed => AudioProcessingState.completed,
            },
      playing: active && player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      queueIndex: index,
    );
  }

  @override
  Future<void> play() => _audio.togglePlayPause(resume: true);

  @override
  Future<void> pause() => _audio.togglePlayPause(resume: false);

  @override
  Future<void> skipToNext() => _audio.next();

  @override
  Future<void> skipToPrevious() => _audio.previous();

  @override
  Future<void> stop() async {
    await _audio.stop();
    playbackState.add(_state(null));
  }
}
