import 'package:flutter/foundation.dart';

/// Hasil satu kali murajaah, dinilai sendiri oleh penghafal.
///
/// Tidak ada penilaian otomatis: aplikasi tidak mendengarkan dan tidak menilai
/// bacaan (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`). Yang menilai orangnya.
enum ReviewOutcome {
  lancar('Lancar', 'Jarak ulangnya dipanjangkan.'),
  ragu('Ragu', 'Jarak ulangnya tetap, supaya diulang lagi secepatnya.'),
  salah('Salah', 'Kembali ke jarak terpendek.');

  const ReviewOutcome(this.label, this.effect);
  final String label;

  /// Kalimat yang ditampilkan ke pengguna, supaya jadwalnya bisa dijelaskan
  /// dan tidak terasa seperti angka yang muncul entah dari mana.
  final String effect;
}

/// Jadwal pengulangan berjarak yang sengaja dibuat sederhana dan bisa
/// dijelaskan: 1 → 3 → 7 → 14 → 30 hari.
///
/// Bukan SM-2 atau varian ber-"ease factor", karena jadwal yang tidak bisa
/// diterangkan ke penggunanya hanya akan terasa seperti tebakan. Tangga ini
/// bisa ditulis apa adanya di layar.
abstract final class MurajaahSchedule {
  /// Tangga jarak ulang dalam hari.
  static const ladder = [1, 3, 7, 14, 30];

  /// Jarak untuk ayat yang baru saja selesai dihafal.
  static const firstInterval = 1;

  /// Jarak berikutnya setelah [outcome] pada ayat yang jarak ulangnya kini
  /// [currentInterval] hari.
  ///
  /// Lancar menaiki satu anak tangga dan berhenti di anak tangga teratas;
  /// ragu bertahan; salah turun ke anak tangga terbawah.
  static int nextInterval(int currentInterval, ReviewOutcome outcome) {
    switch (outcome) {
      case ReviewOutcome.salah:
        return ladder.first;
      case ReviewOutcome.ragu:
        return _clampToLadder(currentInterval);
      case ReviewOutcome.lancar:
        final current = _clampToLadder(currentInterval);
        final index = ladder.indexOf(current);
        return index == ladder.length - 1 ? ladder.last : ladder[index + 1];
    }
  }

  /// Nilai di luar tangga (mis. data lama atau hasil suntingan) ditarik ke
  /// anak tangga terdekat yang tidak melebihinya, bukan ditolak.
  static int _clampToLadder(int interval) {
    if (interval <= ladder.first) return ladder.first;
    return ladder.lastWhere((step) => step <= interval);
  }

  /// Tanggal jatuh tempo berikutnya, dihitung dari [from] tengah malam waktu
  /// setempat supaya "hari ini" tidak bergeser karena jam pengulangan.
  static DateTime dueAfter(DateTime from, int interval) =>
      DateTime(from.year, from.month, from.day + interval);

  /// Penjelasan singkat untuk ditampilkan di layar.
  static String explain(int interval) => switch (interval) {
    <= 1 => 'Diulang besok.',
    7 => 'Diulang sepekan lagi.',
    14 => 'Diulang dua pekan lagi.',
    _ => 'Diulang $interval hari lagi.',
  };
}

/// Catatan hafalan satu ayat.
@immutable
class AyahMemorization {
  const AyahMemorization({
    required this.surah,
    required this.ayah,
    required this.interval,
    required this.dueOn,
  });

  /// Catatan baru untuk ayat yang baru selesai dihafal hari ini.
  factory AyahMemorization.fresh({
    required int surah,
    required int ayah,
    required DateTime today,
  }) => AyahMemorization(
    surah: surah,
    ayah: ayah,
    interval: MurajaahSchedule.firstInterval,
    dueOn: MurajaahSchedule.dueAfter(today, MurajaahSchedule.firstInterval),
  );

  final int surah;
  final int ayah;

  /// Jarak ulang sekarang, dalam hari.
  final int interval;

  /// Tanggal ayat ini perlu diulang, tengah malam waktu setempat.
  final DateTime dueOn;

  String get verseKey => '$surah:$ayah';

  /// Sudah jatuh tempo pada [today]? Yang terlewat ikut terhitung.
  bool isDue(DateTime today) =>
      !dueOn.isAfter(DateTime(today.year, today.month, today.day));

  /// Catatan setelah diulang dengan hasil [outcome].
  AyahMemorization reviewed(ReviewOutcome outcome, DateTime today) {
    final next = MurajaahSchedule.nextInterval(interval, outcome);
    return AyahMemorization(
      surah: surah,
      ayah: ayah,
      interval: next,
      dueOn: MurajaahSchedule.dueAfter(today, next),
    );
  }

  /// `yyyy-MM-dd` waktu setempat, sama seperti kunci tanggal lain di aplikasi.
  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  /// Tanggal dari `yyyy-MM-dd`; null bila bentuknya tidak dikenali.
  static DateTime? parseDate(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  Map<String, dynamic> toJson() => {'i': interval, 'd': formatDate(dueOn)};

  /// Satu entri dari penyimpanan; null bila datanya rusak, supaya ayat yang
  /// tidak terbaca dilewati alih-alih ditebak jadwalnya.
  static AyahMemorization? fromJson(
    int surah,
    int ayah,
    Map<String, dynamic> json,
  ) {
    final interval = json['i'];
    final due = parseDate(json['d'] as String?);
    if (interval is! int || interval < 1 || due == null) return null;
    return AyahMemorization(
      surah: surah,
      ayah: ayah,
      interval: interval,
      dueOn: due,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AyahMemorization &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.interval == interval &&
      other.dueOn == dueOn;

  @override
  int get hashCode => Object.hash(surah, ayah, interval, dueOn);

  @override
  String toString() =>
      'AyahMemorization($verseKey, $interval hari, jatuh tempo '
      '${formatDate(dueOn)})';
}

/// Ayat yang jatuh tempo pada [today], terlama dulu supaya yang paling lama
/// tidak diulang tidak tertinggal di belakang antrean.
List<AyahMemorization> dueForReview(
  Iterable<AyahMemorization> all,
  DateTime today,
) => [
  for (final item in all)
    if (item.isDue(today)) item,
]..sort((a, b) {
  final byDate = a.dueOn.compareTo(b.dueOn);
  if (byDate != 0) return byDate;
  final bySurah = a.surah.compareTo(b.surah);
  return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
});
