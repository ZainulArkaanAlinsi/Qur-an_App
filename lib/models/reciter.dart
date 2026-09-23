import 'package:flutter/foundation.dart';

/// Satu qari murottal per ayat dari Al Quran Cloud.
///
/// [bitrate] berbeda antar qari: CDN hanya menyediakan sebagian dari 64, 128,
/// dan 192 kbps untuk tiap edisi, jadi nilainya dideteksi lalu disimpan,
/// bukan ditebak.
@immutable
class Reciter {
  const Reciter({
    required this.identifier,
    required this.name,
    required this.englishName,
    this.bitrate,
  });

  factory Reciter.fromEdition(Map<String, dynamic> edition) => Reciter(
    identifier: edition['identifier'] as String,
    name: edition['name'] as String? ?? '',
    englishName: edition['englishName'] as String? ?? '',
  );

  factory Reciter.fromJson(Map<String, dynamic> json) => Reciter(
    identifier: json['identifier'] as String,
    name: json['name'] as String? ?? '',
    englishName: json['englishName'] as String? ?? '',
    bitrate: json['bitrate'] as int?,
  );

  /// Edisi Al Quran Cloud, mis. `ar.alafasy`.
  final String identifier;

  /// Nama Arab dari provider.
  final String name;

  /// Nama Latin dari provider.
  final String englishName;

  /// kbps yang terbukti tersedia di CDN, atau `null` bila belum diperiksa.
  final int? bitrate;

  /// Nama untuk ditampilkan; sebagian edisi tidak punya nama Latin.
  String get displayName => englishName.isNotEmpty ? englishName : name;

  Reciter withBitrate(int value) => Reciter(
    identifier: identifier,
    name: name,
    englishName: englishName,
    bitrate: value,
  );

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'name': name,
    'englishName': englishName,
    if (bitrate != null) 'bitrate': bitrate,
  };

  @override
  bool operator ==(Object other) =>
      other is Reciter &&
      other.identifier == identifier &&
      other.bitrate == bitrate;

  @override
  int get hashCode => Object.hash(identifier, bitrate);
}

/// Qari bawaan yang dipakai sebelum daftar berhasil diunduh, dan saat
/// perangkat sedang offline. Bitrate-nya sudah diverifikasi tersedia.
const defaultReciter = Reciter(
  identifier: 'ar.alafasy',
  name: 'مشاري العفاسي',
  englishName: 'Mishary Rashid Alafasy',
  bitrate: 128,
);
