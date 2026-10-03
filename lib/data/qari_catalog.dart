import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/audio_sources.dart';
import 'package:quran_app_2025/models/reciter.dart';

/// Katalog qari terkurasi (`assets/audio/qari_katalog.json`,
/// docs/design/v6/screens/23-qari.md): nama, gaya, suasana, urutan
/// "Populer sekarang", dan sumber audio tiap qari.
///
/// Tag suasana adalah kurasi, bukan fakta tentang qari; tidak ada peringkat.

/// Filter chip pemilih qari, disimpan di preferensi `qari.filter`.
enum QariFilter {
  semua('Semua', null),
  adem('Adem', 'tenang'),
  populer('Populer', 'populer'),
  hafalan('Hafalan', 'hafalan'),
  merdu('Merdu', 'merdu'),
  haramain('Haramain', 'imam_dua_masjid');

  const QariFilter(this.label, this.mood);

  final String label;

  /// Kunci `suasana` di katalog; null = semua.
  final String? mood;

  static QariFilter parse(String? value) =>
      values.where((filter) => filter.name == value).firstOrNull ?? semua;
}

/// Label pendek tag suasana di baris qari.
const moodLabels = {
  'tenang': 'Adem',
  'merdu': 'Merdu',
  'hafalan': 'Hafalan',
  'belajar': 'Belajar',
  'imam_dua_masjid': 'Haramain',
  'populer': 'Populer',
};

/// Satu sumber audio seorang qari.
@immutable
class QariSource {
  const QariSource({required this.source, this.ref, this.perAyat});

  factory QariSource.fromJson(Map<String, dynamic> json) => QariSource(
    source: json['sumber'] as String,
    ref: json['ref'] as String?,
    perAyat: json['perAyat'] as bool?,
  );

  /// Kunci sumber, mis. `islamic_network`.
  final String source;

  /// Identifier di sumber itu; null = belum diketahui dan **tidak pernah**
  /// dipakai untuk membentuk URL.
  final String? ref;
  final bool? perAyat;

  AudioSourceInfo? get info => AudioSources.byId(source);
  bool get granted => info?.granted ?? false;
}

/// Satu qari di katalog.
@immutable
class QariEntry {
  const QariEntry({
    required this.id,
    required this.name,
    required this.style,
    required this.moods,
    required this.country,
    required this.sources,
    this.note,
    this.arabicName,
  });

  factory QariEntry.fromJson(Map<String, dynamic> json) => QariEntry(
    id: json['id'] as String,
    name: json['nama'] as String,
    style: json['gaya'] as String? ?? 'murattal',
    moods: [for (final mood in json['suasana'] as List? ?? const []) '$mood'],
    country: json['negara'] as String? ?? '',
    sources: [
      for (final source in json['sumber'] as List? ?? const [])
        QariSource.fromJson((source as Map).cast<String, dynamic>()),
    ],
    note: json['catatan'] as String?,
  );

  final String id;
  final String name;

  /// `murattal` / `mujawwad` / `muallim`.
  final String style;
  final List<String> moods;
  final String country;
  final List<QariSource> sources;
  final String? note;

  /// Nama Arab dari API sumber (alquran.cloud); null bila tidak ada.
  final String? arabicName;

  /// Punya sumber berizin dengan identifier yang diketahui.
  bool get granted => sources.any((s) => s.granted && s.ref != null);

  /// Sumber yang bisa diputar sekarang. Rilis: hanya Islamic Network
  /// (granted). Debug: juga equran.id per ayat. Sumber lain (Quran
  /// Foundation, QUL, MP3Quran, izin langsung) baru tersambung di 8b/8c.
  QariSource? playableSource({required bool allowPending}) {
    for (final id in [
      AudioSources.islamicNetwork.id,
      if (allowPending) AudioSources.equran.id,
    ]) {
      for (final source in sources) {
        if (source.source != id || source.ref == null) continue;
        if (!source.granted && !allowPending) continue;
        return source;
      }
    }
    return null;
  }

  /// Hanya punya sumber per surah (tanpa per ayat).
  bool get perSurahOnly {
    final known = sources.where((s) => s.ref != null || s.perAyat != null);
    return known.isNotEmpty && known.every((s) => s.perAyat == false);
  }

  /// Satu tag suasana untuk baris: yang pertama selain "populer".
  String? get tag {
    for (final mood in moods) {
      if (mood != 'populer' && moodLabels.containsKey(mood)) {
        return moodLabels[mood];
      }
    }
    return null;
  }

  String get styleLabel => style.isEmpty
      ? ''
      : '${style[0].toUpperCase()}${style.substring(1).toLowerCase()}';

  /// [Reciter] untuk pemutar; null bila tidak ada sumber yang bisa diputar.
  Reciter? toReciter({required bool allowPending}) {
    final source = playableSource(allowPending: allowPending);
    final ref = source?.ref;
    if (source == null || ref == null) return null;
    final style = Reciter.styleOf(this.style);
    if (source.source == AudioSources.equran.id) {
      return Reciter(
        identifier: 'equran:$ref',
        name: arabicName ?? '',
        englishName: name,
        style: style,
        provider: AudioProvider.equran,
      );
    }
    return Reciter(
      identifier: ref,
      name: arabicName ?? '',
      englishName: name,
      style: style,
      perAyat: source.perAyat ?? true,
    );
  }

  /// Apakah [reciter] adalah qari ini (dari sumber mana pun).
  bool matches(Reciter reciter) => sources.any(
    (s) =>
        s.ref != null &&
        (reciter.identifier == s.ref ||
            reciter.identifier == 'equran:${s.ref}' &&
                s.source == AudioSources.equran.id),
  );

  QariEntry withArabicName(String? value) => QariEntry(
    id: id,
    name: name,
    style: style,
    moods: moods,
    country: country,
    sources: sources,
    note: note,
    arabicName: value,
  );
}

@immutable
class QariCatalog {
  const QariCatalog({
    required this.updated,
    required this.popular,
    required this.entries,
    required this.sourceStatus,
  });

  factory QariCatalog.parse(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final sources = (json['sumber'] as Map).cast<String, dynamic>();
    return QariCatalog(
      updated: json['diperbarui'] as String? ?? '',
      popular: [for (final id in json['populer'] as List) '$id'],
      entries: [
        for (final item in json['qari'] as List)
          QariEntry.fromJson((item as Map).cast<String, dynamic>()),
      ],
      sourceStatus: {
        for (final MapEntry(:key, :value) in sources.entries)
          key: '${(value as Map)['status']}',
      },
    );
  }

  static const asset = 'assets/audio/qari_katalog.json';

  static Future<QariCatalog> load() async =>
      QariCatalog.parse(await rootBundle.loadString(asset));

  /// Tanggal kurasi "Populer sekarang", mis. "2026-10-02".
  final String updated;

  /// Urutan bagian "Populer sekarang".
  final List<String> popular;

  /// Urutan katalog (urutan kurasi).
  final List<QariEntry> entries;

  /// Status di JSON (hanya informasi; sumber kebenaran: [AudioSources]).
  final Map<String, String> sourceStatus;

  /// Nama Arab dari daftar alquran.cloud ([editions]), dicocokkan lewat ref.
  QariCatalog withArabicNames(List<Reciter> editions) {
    final names = {
      for (final edition in editions)
        if (edition.name.isNotEmpty) edition.identifier: edition.name,
    };
    return QariCatalog(
      updated: updated,
      popular: popular,
      sourceStatus: sourceStatus,
      entries: [
        for (final entry in entries)
          entry.withArabicName(
            entry.sources
                .map(
                  (s) => s.source == AudioSources.islamicNetwork.id
                      ? names[s.ref]
                      : null,
                )
                .nonNulls
                .firstOrNull,
          ),
      ],
    );
  }

  /// Rilis: hanya qari dengan sumber granted. Debug: semua.
  List<QariEntry> visible({required bool allowPending}) => [
    for (final entry in entries)
      if (allowPending || entry.granted) entry,
  ];

  QariEntry? entryFor(Reciter reciter) =>
      entries.where((entry) => entry.matches(reciter)).firstOrNull;

  /// Daftar untuk [filter] & [query], tanpa qari [exceptId] (bagian Dipilih).
  /// Rilis: urutan kurasi (filter Populer: urutan "Populer sekarang").
  /// Debug: yang menunggu izin dulu, lalu A–Z, supaya mudah diuji.
  List<QariEntry> filtered(
    QariFilter filter, {
    required bool allowPending,
    String query = '',
    String? exceptId,
  }) {
    final words = query.trim().toLowerCase();
    final list = [
      for (final entry in visible(allowPending: allowPending))
        if (entry.id != exceptId &&
            (filter.mood == null ||
                // Chip Populer = daftar kurasi "Populer sekarang".
                (filter == QariFilter.populer
                    ? popular.contains(entry.id)
                    : entry.moods.contains(filter.mood))) &&
            (words.isEmpty ||
                entry.name.toLowerCase().contains(words) ||
                (entry.arabicName?.contains(query.trim()) ?? false)))
          entry,
    ];
    if (allowPending) {
      list.sort((a, b) {
        if (a.granted != b.granted) return a.granted ? 1 : -1;
        return a.name.compareTo(b.name);
      });
    } else if (filter == QariFilter.populer) {
      list.sort((a, b) => _popularRank(a.id).compareTo(_popularRank(b.id)));
    }
    return list;
  }

  int _popularRank(String id) {
    final rank = popular.indexOf(id);
    return rank < 0 ? popular.length : rank;
  }

  /// "Populer sekarang" (urutan [popular]), hanya yang tampil.
  List<QariEntry> popularNow({required bool allowPending, String? exceptId}) {
    final shown = {
      for (final entry in visible(allowPending: allowPending)) entry.id: entry,
    };
    return [
      for (final id in popular)
        if (id != exceptId && shown[id] != null) shown[id]!,
    ];
  }

  /// Semua A–Z (filter Semua, di bawah "Populer sekarang").
  List<QariEntry> alphabetical({
    required bool allowPending,
    String? exceptId,
  }) => [
    for (final entry in visible(allowPending: allowPending))
      if (entry.id != exceptId) entry,
  ]..sort((a, b) => a.name.compareTo(b.name));
}
