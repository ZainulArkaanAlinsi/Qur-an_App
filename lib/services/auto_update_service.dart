import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/services/update_check_service.dart';

/// Hasil satu siklus pembaruan otomatis.
enum AutoUpdateOutcome {
  /// Tidak ada versi baru, fitur dimatikan, atau bukan Android.
  nothingToDo,

  /// APK siap tetapi pengguna belum mengizinkan pemasangan dari aplikasi ini.
  needsInstallPermission,

  /// Dialog pemasangan Android sudah dibuka.
  installerOpened,

  /// Gagal mengunduh atau berkasnya tidak utuh.
  failed,
}

/// Jembatan ke pemasang paket Android.
///
/// Android **selalu** menampilkan dialog konfirmasi saat memasang APK di luar
/// Play Store, dan memerlukan izin "pasang aplikasi tak dikenal" satu kali.
/// Jadi pembaruan otomatis sampai tahap membuka pemasang, bukan sampai
/// selesai terpasang.
class ApkInstaller {
  const ApkInstaller();

  static const channel = MethodChannel('ruang_tilawah/installer');

  Future<bool> canInstall() async =>
      await channel.invokeMethod<bool>('canInstall') ?? false;

  /// Membuka layar izin sistem. Pengguna yang memutuskan.
  Future<void> openPermissionSettings() =>
      channel.invokeMethod<void>('openInstallPermissionSettings');

  Future<void> install(String path) =>
      channel.invokeMethod<void>('install', {'path': path});
}

/// Mengunduh APK rilis terbaru di latar belakang lalu membuka pemasang.
///
/// APK hanya dapat memperbarui aplikasi ini bila ditandatangani kunci rilis
/// yang sama — Android menolak tanda tangan berbeda, sehingga berkas asing
/// tidak bisa menggantikan aplikasi.
class AutoUpdateService {
  AutoUpdateService({
    http.Client? client,
    ApkInstaller installer = const ApkInstaller(),
    Future<Directory> Function()? downloadDirectory,
    Future<AvailableUpdate?> Function()? checkForUpdate,
    bool isSupported = true,
  }) : _client = client,
       _installer = installer,
       _downloadDirectory = downloadDirectory ?? getApplicationSupportDirectory,
       _checkForUpdate = checkForUpdate ?? UpdateCheckService.checkDaily,
       _isSupported = isSupported;

  final http.Client? _client;
  final ApkInstaller _installer;
  final Future<Directory> Function() _downloadDirectory;
  final Future<AvailableUpdate?> Function() _checkForUpdate;
  final bool _isSupported;

  /// Pembaruan terakhir yang ditemukan `run`, agar pemanggil dapat mencoba
  /// memasang lagi setelah pengguna memberi izin.
  AvailableUpdate? lastUpdate;

  /// Membuka layar izin lalu, bila izin diberikan, langsung memasang berkas
  /// yang sudah diunduh. Tanpa ini pengguna memberi izin tetapi pembaruannya
  /// baru ditawarkan lagi besok.
  Future<AutoUpdateOutcome> installAfterPermission(AvailableUpdate update)
  async {
    await _installer.openPermissionSettings();
    if (!await _installer.canInstall()) {
      return AutoUpdateOutcome.needsInstallPermission;
    }
    final apk = update.apkUrl;
    if (apk == null) return AutoUpdateOutcome.nothingToDo;
    final file = await _download(update, apk);
    if (file == null) return AutoUpdateOutcome.failed;
    await _installer.install(file.path);
    return AutoUpdateOutcome.installerOpened;
  }

  /// Dipanggil saat aplikasi dibuka. Tidak pernah melempar: kegagalan
  /// pembaruan tidak boleh mengganggu membaca.
  Future<AutoUpdateOutcome> run({required bool enabled}) async {
    if (!enabled || !_isSupported) return AutoUpdateOutcome.nothingToDo;
    try {
      final update = await _checkForUpdate();
      lastUpdate = update;
      final apk = update?.apkUrl;
      if (update == null || apk == null) return AutoUpdateOutcome.nothingToDo;

      final file = await _download(update, apk);
      if (file == null) return AutoUpdateOutcome.failed;

      if (!await _installer.canInstall()) {
        return AutoUpdateOutcome.needsInstallPermission;
      }
      await _installer.install(file.path);
      return AutoUpdateOutcome.installerOpened;
    } on Object catch (error) {
      debugPrint('Pembaruan otomatis gagal: $error');
      return AutoUpdateOutcome.failed;
    }
  }

  /// Mengunduh APK bila belum ada. Berkas dengan ukuran berbeda dari metadata
  /// rilis dianggap rusak dan dibuang, bukan dipasang.
  Future<File?> _download(AvailableUpdate update, Uri apk) async {
    final directory = await _downloadDirectory();
    final file = File('${directory.path}/ruang-tilawah-${update.version}.apk');
    final expected = update.apkSize;

    if (file.existsSync()) {
      final length = file.lengthSync();
      // Tanpa ukuran dari metadata rilis, berkas lama tidak dapat dipastikan
      // utuh; unduh ulang daripada memasang berkas yang mungkin terpotong.
      if (expected != null && length == expected) return file;
      file.deleteSync();
    }

    final client = _client ?? http.Client();
    try {
      final response = await client.get(apk).timeout(
        const Duration(minutes: 10),
      );
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      if (expected != null && bytes.length != expected) return null;
      file.writeAsBytesSync(bytes, flush: true);
      return file;
    } finally {
      if (_client == null) client.close();
    }
  }
}
