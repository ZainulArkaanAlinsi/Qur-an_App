import 'package:flutter/foundation.dart';

/// Status izin satu sumber audio murottal (docs/design/v6/screens/23-qari.md).
enum LicenseStatus { granted, pending }

/// Satu sumber audio dan syarat pakainya.
@immutable
class AudioSourceInfo {
  const AudioSourceInfo({
    required this.id,
    required this.name,
    required this.status,
    this.perAyat,
    this.downloadable = true,
  });

  /// Kunci yang sama dengan `sumber` di `assets/audio/qari_katalog.json`.
  final String id;
  final String name;
  final LicenseStatus status;

  /// Berkas per ayat (true), per surah (false), atau belum diketahui.
  final bool? perAyat;

  /// Boleh diunduh ke perangkat. Quran Foundation: Developer Terms melarang
  /// menyimpan konten > 7 hari, jadi Unduh disembunyikan.
  final bool downloadable;

  bool get granted => status == LicenseStatus.granted;
}

/// Registri izin. **Sumber kebenaran status** (bukan JSON katalog): status
/// diubah hanya setelah bukti izin disimpan di `docs/lisensi/bukti/`, dalam
/// commit tersendiri yang menyebut buktinya. Tes memastikan JSON sama.
abstract final class AudioSources {
  static const islamicNetwork = AudioSourceInfo(
    id: 'islamic_network',
    name: 'Islamic Network (alquran.cloud)',
    status: LicenseStatus.granted,
    perAyat: true,
  );
  static const equran = AudioSourceInfo(
    id: 'equran',
    name: 'equran.id',
    status: LicenseStatus.pending,
    perAyat: true,
  );
  static const quranFoundation = AudioSourceInfo(
    id: 'quran_foundation',
    name: 'Quran Foundation (quran.com) lewat bff/',
    status: LicenseStatus.pending,
    perAyat: true,
    downloadable: false,
  );
  static const qul = AudioSourceInfo(
    id: 'qul',
    name: 'QUL / Tarteel',
    status: LicenseStatus.pending,
  );
  static const mp3quran = AudioSourceInfo(
    id: 'mp3quran',
    name: 'MP3Quran',
    status: LicenseStatus.pending,
    perAyat: false,
  );
  static const direct = AudioSourceInfo(
    id: 'langsung',
    name: 'Izin langsung dari qari',
    status: LicenseStatus.pending,
  );

  static const all = [
    islamicNetwork,
    equran,
    quranFoundation,
    qul,
    mp3quran,
    direct,
  ];

  static AudioSourceInfo? byId(String id) =>
      all.where((source) => source.id == id).firstOrNull;

  /// Sumber berstatus pending ikut dipakai hanya di build debug: daftar
  /// qari "MENUNGGU IZIN" dan cadangan equran.id/MP3Quran saat CDN utama
  /// gagal. Build rilis hanya memakai sumber granted (keputusan 2026-10-03).
  static bool get allowPending => debugAllowPending ?? kDebugMode;

  /// Hanya untuk tes: meniru build rilis (false) atau debug (true).
  @visibleForTesting
  static bool? debugAllowPending;
}
