import 'package:flutter/material.dart';

/// Status hafalan satu surah. Disimpan lokal apa adanya; aplikasi tidak
/// menilai bacaan dan tidak memberi skor otomatis.
enum MemorizationStatus {
  notStarted('Belum mulai', Icons.circle_outlined),
  learning('Sedang dihafal', Icons.timelapse_rounded),
  memorized('Hafal', Icons.verified_rounded),
  needsReview('Perlu murajaah', Icons.refresh_rounded);

  const MemorizationStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Urutan saat chip status diketuk berulang.
  MemorizationStatus get next =>
      MemorizationStatus.values[(index + 1) % MemorizationStatus.values.length];
}

/// Naik setiap kali status hafalan berubah, sehingga tab Belajar dan Hafalan
/// yang sama-sama hidup di IndexedStack tidak menampilkan daftar basi.
final memorizationRevision = ValueNotifier<int>(0);
