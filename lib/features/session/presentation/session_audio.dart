/// Suara di langkah "Dengar & tirukan": qari lewat [QuranAudioService] dan
/// rekaman sendiri lewat paket `record`. Keduanya dibungkus antarmuka supaya
/// layar sesi bisa diuji tanpa pemutar dan mikrofon sungguhan.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:record/record.dart';

/// Qari untuk satu ayat, dan penjaga antrean murottal yang sedang berjalan.
abstract class SessionAudio {
  /// Audio ayat ini sudah terunduh, jadi bisa diputar tanpa internet.
  Future<bool> hasOffline(int surah, int ayah);

  /// Memutar qari untuk satu ayat [times] kali; selesai setelah berhenti.
  /// Melempar bila audionya tidak bisa dimuat (mis. offline dan belum
  /// terunduh).
  Future<void> playQari(int surah, int ayah, {int times = 1, double speed = 1});

  Future<void> stopQari();

  /// Menghentikan murottal yang sedang berjalan dengan menyimpan posisinya.
  /// Aman dipanggil berkali-kali; hanya panggilan pertama yang menyimpan.
  Future<void> borrow();

  /// Mengembalikan murottal dan kecepatan seperti sebelum [borrow].
  Future<void> giveBack();
}

/// Perekam bacaan. Rekaman hanya ditulis ke berkas lokal.
abstract class SessionRecorder {
  /// Meminta izin mikrofon bila belum pernah ditanyakan.
  Future<bool> hasPermission();

  Future<void> start(String path);

  /// Menghentikan rekaman; mengembalikan path berkasnya.
  Future<String?> stop();

  /// Kekerasan suara 0–1 selama merekam, untuk bar amplitudo.
  Stream<double> amplitude();

  /// Memutar berkas rekaman; selesai setelah berhenti.
  Future<void> play(String path);

  Future<void> stopPlayback();

  Future<void> dispose();
}

/// [SessionAudio] memakai pemutar murottal aplikasi.
class DeviceSessionAudio implements SessionAudio {
  DeviceSessionAudio([QuranAudioService? audio])
    : _audio = audio ?? QuranAudioService.instance;

  final QuranAudioService _audio;
  bool _borrowed = false;
  AudioResumePoint? _resume;
  double? _speed;

  @override
  Future<bool> hasOffline(int surah, int ayah) async {
    try {
      final reciter = SharedPreferencesService.getReciter();
      final folder = await AudioDownloadService().folderPath(reciter);
      if (folder == null) return false;
      final file = File('$folder/${globalAyahNumber(surah, ayah)}.mp3');
      return file.existsSync() && file.lengthSync() > 0;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> playQari(
    int surah,
    int ayah, {
    int times = 1,
    double speed = 1,
  }) async {
    await borrow();
    await _audio.setSpeed(speed);
    await _audio.playRange(
      surah: surah,
      fromAyah: ayah,
      toAyah: ayah,
      repeatCount: times,
    );
    // Pemutar menutup antreannya sendiri setelah putaran terakhir.
    final done = Completer<void>();
    void check() {
      if (_audio.queue.value == null && !done.isCompleted) done.complete();
    }

    _audio.queue.addListener(check);
    check();
    try {
      await done.future;
    } finally {
      _audio.queue.removeListener(check);
    }
  }

  @override
  Future<void> stopQari() => _audio.stop();

  @override
  Future<void> borrow() async {
    if (_borrowed) return;
    _borrowed = true;
    _speed = _audio.speed.value;
    _resume = _audio.resumePoint();
    if (_audio.queue.value != null) await _audio.stop();
  }

  @override
  Future<void> giveBack() async {
    if (!_borrowed) return;
    _borrowed = false;
    await _audio.stop();
    if (_speed case final speed?) await _audio.setSpeed(speed);
    if (_resume case final point?) await _audio.restore(point);
    _resume = null;
  }
}

/// [SessionRecorder] dengan paket `record` dan pemutar `just_audio`.
class DeviceSessionRecorder implements SessionRecorder {
  AudioRecorder? _recorder;
  AudioPlayer? _player;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start(String path) =>
      _rec.start(const RecordConfig(), path: path);

  @override
  Future<String?> stop() async => _recorder?.stop();

  /// dBFS −45…0 dipetakan ke 0…1; di bawah −45 dianggap hening.
  @override
  Stream<double> amplitude() => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((value) => ((value.current + 45) / 45).clamp(0.0, 1.0).toDouble());

  @override
  Future<void> play(String path) async {
    final player = _player ??= AudioPlayer();
    await player.setFilePath(path);
    await player.play();
    await player.stop();
  }

  @override
  Future<void> stopPlayback() async => _player?.stop();

  @override
  Future<void> dispose() async {
    try {
      if (await _recorder?.isRecording() ?? false) await _recorder?.stop();
    } on Object {
      debugPrint('Perekam sesi sudah tertutup.');
    }
    await _recorder?.dispose();
    await _player?.dispose();
  }
}
