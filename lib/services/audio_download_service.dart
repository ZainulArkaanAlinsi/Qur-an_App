import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';

/// Kemajuan unduhan satu surah.
@immutable
class DownloadProgress {
  const DownloadProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done >= total;
}

/// Mengunduh murottal per ayat agar dapat diputar tanpa internet.
///
/// Ketentuan Al Quran Cloud mengizinkan pengunduhan untuk pemakaian pribadi;
/// berkas disimpan di folder aplikasi, tidak dibagikan keluar, dan dapat
/// dihapus pengguna kapan saja.
class AudioDownloadService {
  AudioDownloadService({
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client,
       _directory = directory ?? getApplicationSupportDirectory;

  final http.Client? _client;
  final Future<Directory> Function() _directory;
  final _cancelled = <String>{};

  static String _key(String edition, int surah) => '$edition/$surah';

  Future<Directory> _folderFor(String edition) async {
    final base = await _directory();
    final folder = Directory('${base.path}/murottal/$edition');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return folder;
  }

  /// Folder murottal qari tersebut; dipakai pemutar untuk memeriksa berkas
  /// lokal sekali per antrean, bukan sekali per ayat.
  Future<String> folderPath(Reciter reciter) async =>
      (await _folderFor(reciter.identifier)).path;

  /// Berkas lokal satu ayat, ada atau belum.
  Future<File> fileFor(Reciter reciter, int surah, int ayah) async {
    final folder = await _folderFor(reciter.identifier);
    return File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
  }

  /// Surah dianggap tersedia offline hanya bila **semua** ayatnya ada.
  Future<bool> isComplete(Reciter reciter, int surah) async {
    final folder = await _folderFor(reciter.identifier);
    for (var ayah = 1; ayah <= surahCatalog[surah - 1].ayahCount; ayah++) {
      final file = File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  /// Ukuran seluruh berkas qari ini di perangkat, dalam byte.
  Future<int> storageUsed(Reciter reciter) async {
    final folder = await _folderFor(reciter.identifier);
    var total = 0;
    for (final entity in folder.listSync()) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  void cancel(Reciter reciter, int surah) =>
      _cancelled.add(_key(reciter.identifier, surah));

  /// Mengunduh ayat yang belum ada. Ayat yang gagal membuat unduhan berhenti
  /// dan `false` dikembalikan, sehingga surah tidak pernah dianggap lengkap
  /// padahal berlubang.
  Future<bool> download(
    Reciter reciter,
    int surah, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final key = _key(reciter.identifier, surah);
    _cancelled.remove(key);
    final folder = await _folderFor(reciter.identifier);
    final total = surahCatalog[surah - 1].ayahCount;
    final client = _client ?? http.Client();
    try {
      for (var ayah = 1; ayah <= total; ayah++) {
        if (_cancelled.contains(key)) return false;
        final file = File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
        if (!file.existsSync() || file.lengthSync() == 0) {
          final uri = Uri.https(
            'cdn.islamic.network',
            '/quran/audio/${reciter.bitrate ?? 128}/${reciter.identifier}/'
                '${globalAyahNumber(surah, ayah)}.mp3',
          );
          final response = await client
              .get(uri)
              .timeout(const Duration(seconds: 60));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            debugPrint('Unduhan ayat $surah:$ayah gagal');
            return false;
          }
          file.writeAsBytesSync(response.bodyBytes, flush: true);
        }
        onProgress?.call(DownloadProgress(done: ayah, total: total));
      }
      return true;
    } on Object catch (error) {
      debugPrint('Unduhan murottal berhenti: $error');
      return false;
    } finally {
      if (_client == null) client.close();
      _cancelled.remove(key);
    }
  }

  /// Menghapus seluruh berkas satu surah untuk qari tersebut.
  Future<void> delete(Reciter reciter, int surah) async {
    final folder = await _folderFor(reciter.identifier);
    for (var ayah = 1; ayah <= surahCatalog[surah - 1].ayahCount; ayah++) {
      final file = File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Menghapus seluruh murottal qari tersebut.
  Future<void> deleteAll(Reciter reciter) async {
    final folder = await _folderFor(reciter.identifier);
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  }
}
