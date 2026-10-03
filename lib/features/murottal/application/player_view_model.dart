import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Turunan status pemutar untuk layar Murottal (docs/DATA.md §5.2).
///
/// Fungsi murni: tidak membaca pemutar atau jam, hanya nilai yang dioper,
/// supaya bisa dites dengan tabel.
@immutable
class PlayerView {
  const PlayerView._(this.queue, this.index);

  /// Null bila tidak ada yang diputar atau [playingVerse] di luar antrean.
  static PlayerView? of(AudioQueue? queue, String? playingVerse) {
    if (queue == null || playingVerse == null) return null;
    final parts = playingVerse.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts.first);
    final ayah = int.tryParse(parts.last);
    if (surah != queue.surah || ayah == null) return null;
    if (ayah < queue.firstAyah || ayah > queue.lastAyah) return null;
    return PlayerView._(queue, ayah - queue.firstAyah);
  }

  final AudioQueue queue;

  /// Indeks ayat yang diputar dalam antrean (0-based).
  final int index;

  /// Lebih dari ini, kemajuan memakai satu bar kontinu (DATA.md §5.2).
  static const segmentLimit = 40;

  static const speeds = [0.75, 1.0, 1.25, 1.5];

  int get surah => queue.surah;
  int get ayah => queue.ayahAt(index);
  int get total => queue.length;
  bool get segmentMode => total <= segmentLimit;
  bool get isFirst => index == 0;
  bool get isLast => index == total - 1;

  /// "Ayat 5 dari 7" bila antrean mulai dari ayat 1; selain itu
  /// "Ayat 12 · 3 dari 10".
  String get label => queue.firstAyah == 1
      ? 'Ayat $ayah dari ${queue.lastAyah}'
      : 'Ayat $ayah · ${index + 1} dari $total';

  /// Isi pill Rentang, mis. "1–7".
  String get rangeLabel => '${queue.firstAyah}–${queue.lastAyah}';

  /// Isi segmen aktif (mode segmen) atau seluruh bar (kontinu); tidak
  /// pernah > 1.
  double fill(double fraction) => segmentMode
      ? fraction.clamp(0.0, 1.0)
      : continuousFill(total, index, fraction);

  static double continuousFill(int total, int index, double fraction) {
    if (total <= 0) return 0;
    return ((index + fraction.clamp(0.0, 1.0)) / total).clamp(0.0, 1.0);
  }

  /// Posisi di ayat (0..1); 0 bila durasi belum diketahui.
  static double fractionOf(Duration position, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// "0:01 / 0:06"; durasi yang belum diketahui ditulis "–:––".
  static String timeLabel(Duration position, Duration? duration) {
    final end = duration == null || duration <= Duration.zero ? null : duration;
    final at = end != null && position > end ? end : position;
    return '${clock(at)} / ${end == null ? '–:––' : clock(end)}';
  }

  static String clock(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Jam berhentinya timer, mis. "10:52".
  static String clockOfDay(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// "1×", "1.25×", "0.75×".
  static String speedLabel(double speed) {
    final text = speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$text×';
  }

  /// Siklus kecepatan 0.75 → 1 → 1.25 → 1.5 → 0.75.
  static double nextSpeed(double current) {
    final at = speeds.indexWhere((step) => (step - current).abs() < .01);
    return speeds[(at + 1) % speeds.length];
  }

  /// Siklus tombol Ulang: Mati → Ulang ayat → Ulang rentang (bila antrean
  /// lebih dari satu ayat) → Mati.
  static AudioRepeat nextRepeat(
    AudioRepeat current, {
    required bool hasRange,
  }) => switch (current) {
    AudioRepeat.off => AudioRepeat.verse,
    AudioRepeat.verse => hasRange ? AudioRepeat.range : AudioRepeat.off,
    AudioRepeat.range => AudioRepeat.off,
  };
}
