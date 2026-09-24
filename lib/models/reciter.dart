import 'package:flutter/foundation.dart';

/// Gaya bacaan qari.
///
/// Dibedakan karena kebutuhannya berbeda: murattal untuk menemani membaca,
/// mujawwad untuk didengarkan, muallim untuk ditirukan saat belajar.
enum RecitationStyle {
  murattal('Murattal', 'Tartil, tempo tenang — untuk menemani membaca.'),
  mujawwad('Mujawwad', 'Bacaan bertajwid dengan lagu, untuk didengarkan.'),
  muallim('Muallim', 'Dibaca lalu dijeda untuk ditirukan — untuk belajar.'),
  unknown('Lainnya', 'Gaya bacaannya belum dipastikan.');

  const RecitationStyle(this.label, this.description);
  final String label;
  final String description;
}

/// Riwayat bacaan. Aplikasi ini memakai teks Hafs 'an 'Ashim, jadi hanya
/// [hafs] yang boleh ditampilkan; yang lain disaring supaya teks di layar dan
/// suara yang terdengar tidak pernah berbeda riwayat.
enum Narration {
  hafs('Hafs'),
  other('Riwayat lain');

  const Narration(this.label);
  final String label;
}

/// Penyedia berkas audio, beserta atribusi yang wajib ikut ditampilkan.
enum AudioProvider {
  alQuranCloud(
    'Al Quran Cloud',
    'Islamic Network CDN (alquran.cloud). Hak cipta rekaman milik qari.',
  ),
  // EveryAyah sengaja tidak dipakai: lisensinya tidak jelas
  // (API-Qur'an-gratis.md).
  quranFoundation(
    'Quran Foundation',
    'quran.foundation. Hak cipta rekaman milik qari.',
  );

  const AudioProvider(this.label, this.attribution);
  final String label;
  final String attribution;
}

/// Satu qari murottal per ayat.
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
    this.style = RecitationStyle.unknown,
    this.narration = Narration.hafs,
    this.provider = AudioProvider.alQuranCloud,
    this.hasWordTiming = false,
  });

  factory Reciter.fromEdition(Map<String, dynamic> edition) {
    final english = edition['englishName'] as String? ?? '';
    final identifier = edition['identifier'] as String;
    return Reciter(
      identifier: identifier,
      name: edition['name'] as String? ?? '',
      englishName: english,
      // Sebagian edisi menyebut gayanya hanya di identifier
      // (`ar.abdulbasitmurattal`), bukan di nama.
      style: styleOf('$english $identifier'),
      narration: narrationOf(english),
    );
  }

  factory Reciter.fromJson(Map<String, dynamic> json) {
    final english = json['englishName'] as String? ?? '';
    return Reciter(
      identifier: json['identifier'] as String,
      name: json['name'] as String? ?? '',
      englishName: english,
      bitrate: json['bitrate'] as int?,
      // Cache lama tidak punya field ini; nilainya diturunkan ulang dari nama
      // supaya entri lama tetap terbaca alih-alih dibuang.
      style: _styleByName(json['style'] as String?) ?? styleOf(english),
      narration:
          _narrationByName(json['narration'] as String?) ??
          narrationOf(english),
      provider:
          _providerByName(json['provider'] as String?) ??
          AudioProvider.alQuranCloud,
      hasWordTiming: json['hasWordTiming'] as bool? ?? false,
    );
  }

  /// Gaya bacaan yang disebutkan penyedia pada nama edisinya.
  ///
  /// Penyedia tidak punya field terpisah untuk ini, jadi satu-satunya
  /// keterangan yang ada memang ada di namanya. Kalau tidak disebut, gayanya
  /// dinyatakan belum dipastikan — bukan ditebak murattal.
  static RecitationStyle styleOf(String englishName) {
    final lower = englishName.toLowerCase();
    if (lower.contains('muallim') || lower.contains("mu'allim")) {
      return RecitationStyle.muallim;
    }
    if (lower.contains('mujawwad')) return RecitationStyle.mujawwad;
    if (lower.contains('murattal')) return RecitationStyle.murattal;
    return RecitationStyle.unknown;
  }

  /// Riwayat yang disebutkan penyedia pada nama edisinya.
  ///
  /// Hanya menandai yang **jelas** bukan Hafs. Edisi yang tidak menyebut
  /// riwayat diperlakukan sebagai Hafs, karena itulah bawaan seluruh penyedia
  /// yang dipakai di sini.
  static Narration narrationOf(String englishName) {
    final lower = englishName.toLowerCase();
    const others = ['warsh', 'qalun', 'qaloon', "shu'bah", 'shubah', 'duri'];
    return others.any(lower.contains) ? Narration.other : Narration.hafs;
  }

  static RecitationStyle? _styleByName(String? value) =>
      RecitationStyle.values.where((item) => item.name == value).firstOrNull;

  static Narration? _narrationByName(String? value) =>
      Narration.values.where((item) => item.name == value).firstOrNull;

  static AudioProvider? _providerByName(String? value) =>
      AudioProvider.values.where((item) => item.name == value).firstOrNull;

  /// Edisi Al Quran Cloud, mis. `ar.alafasy`.
  final String identifier;

  /// Nama Arab dari provider.
  final String name;

  /// Nama Latin dari provider.
  final String englishName;

  /// kbps yang terbukti tersedia di CDN, atau `null` bila belum diperiksa.
  final int? bitrate;

  final RecitationStyle style;
  final Narration narration;
  final AudioProvider provider;

  /// Punya data waktu per kata, sehingga sorot per kata boleh dinyalakan.
  /// Tanpa data ini timestamp tidak boleh dikarang.
  final bool hasWordTiming;

  /// Atribusi penyedia, untuk layar Sumber & lisensi.
  String get attribution => provider.attribution;

  /// Nama untuk ditampilkan; sebagian edisi tidak punya nama Latin.
  String get displayName => englishName.isNotEmpty ? englishName : name;

  Reciter withBitrate(int value) => copyWith(bitrate: value);

  Reciter copyWith({int? bitrate}) => Reciter(
    identifier: identifier,
    name: name,
    englishName: englishName,
    bitrate: bitrate ?? this.bitrate,
    style: style,
    narration: narration,
    provider: provider,
    hasWordTiming: hasWordTiming,
  );

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'name': name,
    'englishName': englishName,
    if (bitrate != null) 'bitrate': bitrate,
    'style': style.name,
    'narration': narration.name,
    'provider': provider.name,
    if (hasWordTiming) 'hasWordTiming': true,
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
  style: RecitationStyle.murattal,
);
