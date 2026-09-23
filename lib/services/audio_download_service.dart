import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/reciter.dart';

/// Hasil akhir satu unduhan. Dibatalkan pengguna dibedakan dari gagal, agar
/// pesan ke pengguna tidak keliru.
enum DownloadOutcome { completed, cancelled, failed }

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

  /// Penyimpanan bisa penuh atau tidak tersedia. Pemanggil menerima `null`
  /// dan menampilkan keadaan normal, bukan macet di indikator berputar.
  Future<Directory?> _folderOrNull(String edition) async {
    try {
      return await _folderFor(edition);
    } on Object catch (error) {
      debugPrint('Folder murottal tidak dapat dibuka: $error');
      return null;
    }
  }

  /// Folder murottal qari tersebut; dipakai pemutar untuk memeriksa berkas
  /// lokal sekali per antrean, bukan sekali per ayat.
  Future<String?> folderPath(Reciter reciter) async =>
      (await _folderOrNull(reciter.identifier))?.path;

  /// Berkas lokal satu ayat, ada atau belum.
  Future<File> fileFor(Reciter reciter, int surah, int ayah) async {
    final folder = await _folderFor(reciter.identifier);
    return File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
  }

  /// Surah dianggap tersedia offline hanya bila **semua** ayatnya ada.
  Future<bool> isComplete(Reciter reciter, int surah) async {
    final folder = await _folderOrNull(reciter.identifier);
    if (folder == null) return false;
    for (var ayah = 1; ayah <= surahCatalog[surah - 1].ayahCount; ayah++) {
      final file = File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  /// Ukuran seluruh berkas qari ini di perangkat, dalam byte.
  Future<int> storageUsed(Reciter reciter) async {
    final folder = await _folderOrNull(reciter.identifier);
    if (folder == null) return 0;
    var total = 0;
    for (final entity in folder.listSync()) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  /// Perkiraan ukuran unduhan satu surah, dari ukuran ayat pertama dikali
  /// jumlah ayat. Hanya perkiraan: panjang tiap ayat berbeda. `null` bila
  /// server tidak memberi ukuran.
  Future<int?> estimateSize(Reciter reciter, int surah) async {
    final client = _client ?? http.Client();
    try {
      final uri = Uri.https(
        'cdn.islamic.network',
        '/quran/audio/${reciter.bitrate ?? 128}/${reciter.identifier}/'
            '${globalAyahNumber(surah, 1)}.mp3',
      );
      final response = await client
          .head(uri)
          .timeout(const Duration(seconds: 15));
      final length = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if (response.statusCode != 200 || length == null || length <= 0) {
        return null;
      }
      return length * surahCatalog[surah - 1].ayahCount;
    } on Object catch (error) {
      debugPrint('Perkiraan ukuran gagal: $error');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  void cancel(Reciter reciter, int surah) =>
      _cancelled.add(_key(reciter.identifier, surah));

  /// Mengunduh ayat yang belum ada. Ayat yang gagal membuat unduhan berhenti
  /// dan `false` dikembalikan, sehingga surah tidak pernah dianggap lengkap
  /// padahal berlubang.
  Future<DownloadOutcome> download(
    Reciter reciter,
    int surah, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final key = _key(reciter.identifier, surah);
    _cancelled.remove(key);
    final folder = await _folderOrNull(reciter.identifier);
    if (folder == null) return DownloadOutcome.failed;
    final total = surahCatalog[surah - 1].ayahCount;
    final client = _client ?? http.Client();
    try {
      for (var ayah = 1; ayah <= total; ayah++) {
        if (_cancelled.contains(key)) return DownloadOutcome.cancelled;
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
            return DownloadOutcome.failed;
          }
          // Tulis ke berkas sementara lalu ganti nama: proses yang terhenti
          // di tengah tidak meninggalkan berkas terpotong yang dikira utuh.
          final temp = File('${file.path}.part');
          temp.writeAsBytesSync(response.bodyBytes, flush: true);
          temp.renameSync(file.path);
        }
        onProgress?.call(DownloadProgress(done: ayah, total: total));
      }
      return DownloadOutcome.completed;
    } on Object catch (error) {
      debugPrint('Unduhan murottal berhenti: $error');
      return DownloadOutcome.failed;
    } finally {
      if (_client == null) client.close();
      _cancelled.remove(key);
    }
  }

  /// Menghapus seluruh berkas satu surah untuk qari tersebut.
  Future<void> delete(Reciter reciter, int surah) async {
    final folder = await _folderOrNull(reciter.identifier);
    if (folder == null) return;
    for (var ayah = 1; ayah <= surahCatalog[surah - 1].ayahCount; ayah++) {
      final file = File('${folder.path}/${globalAyahNumber(surah, ayah)}.mp3');
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Menghapus seluruh murottal qari tersebut.
  Future<void> deleteAll(Reciter reciter) async {
    final folder = await _folderOrNull(reciter.identifier);
    if (folder != null && folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
  }
}
