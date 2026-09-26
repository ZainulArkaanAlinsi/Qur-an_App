import 'package:flutter/widgets.dart';

/// Angka gerak kaca (LIQUID_GLASS.md §6). Dipakai bersama oleh tab bar, nav
/// pembaca, mini player, dan sheet supaya semuanya terasa satu keluarga.
abstract final class GlassMotion {
  /// Pegas lensa tab: massa 1, kekakuan 420, redaman 32 (sekitar 350 ms,
  /// lewatan kurang dari 4%).
  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 32);

  /// Kurva v3 (docs/design/v3/DESIGN.md), sama dengan `brandEase`.
  static const ease = Cubic(0.22, 1, 0.36, 1);

  /// Regangan lensa maksimal searah gerak; tinggi berkurang setengahnya.
  static const maxStretch = .12;

  /// Kecepatan lensa (tab per detik) yang dianggap regangan penuh. Pindah
  /// satu tab dengan pegas di atas memuncak sekitar 9 tab/detik.
  static const stretchVelocity = 10.0;

  /// Lensa mengecil saat ditekan.
  static const pressScale = .94;
  static const press = Duration(milliseconds: 90);

  /// Nav pembaca sembunyi/muncul.
  static const navToggle = Duration(milliseconds: 220);

  /// Jarak gulir turun sebelum nav pembaca disembunyikan.
  static const navHideDistance = 24.0;

  /// Mini player muncul dari bawah.
  static const miniPlayer = Duration(milliseconds: 280);

  /// Pengganti semua gerak saat "Kurangi gerak" aktif.
  static const reducedFade = Duration(milliseconds: 150);
}
