import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Pilihan "Mulai dari mana?" di onboarding halaman 4
/// (docs/design/v3/DESIGN.md §5b). Nilainya disimpan di `belajar.titikMulai`
/// dan bisa diubah lagi di Saya → Belajar.
enum StartPoint {
  /// Belum bisa membaca huruf Arab: tab Belajar di tahap 1.
  nol(
    id: 'nol',
    title: 'Belum bisa membaca huruf Arab',
    subtitle: 'Mulai dari tahap 1: huruf hijaiyah',
    level: 1,
  ),

  /// Sudah bisa, ingin lancar tajwid: tab Belajar di tahap 10.
  tajwid(
    id: 'tajwid',
    title: 'Sudah bisa, ingin lancar tajwid',
    subtitle: 'Mulai dari tahap 10: nun sukun & tanwin',
    level: 10,
  ),

  /// Ingin fokus menghafal: tab Hafalan.
  hafalan(
    id: 'hafalan',
    title: 'Ingin fokus menghafal',
    subtitle: 'Buka Hafalan dengan target harian',
    level: 0,
  );

  const StartPoint({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Tahap pertama yang dituju di jalur Belajar.
  final int level;

  /// Nilai ringkas di baris Saya → Belajar.
  String get shortLabel => switch (this) {
    nol => 'Tahap 1',
    tajwid => 'Tahap 10',
    hafalan => 'Hafalan',
  };

  /// Pilihan awal di onboarding: nomor 2.
  static const initial = StartPoint.tajwid;

  static StartPoint? fromId(String? id) {
    for (final point in values) {
      if (point.id == id) return point;
    }
    return null;
  }

  /// Pilihan tersimpan, atau null bila belum pernah memilih.
  static StartPoint? get saved =>
      fromId(SharedPreferencesService.getStartPoint());

  /// Tab tujuan setelah tombol Mulai: Belajar (2) atau Hafalan (3).
  int get tabIndex => this == hafalan ? 3 : 2;
}
