import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Tingkat kualitas kaca (LIQUID_GLASS.md §4). Bentuk dan ukuran sama di
/// semua tingkat; yang berubah hanya blur dan alfa tint.
enum GlassTier { full, lite, solid }

/// Pilihan pengguna di Saya → Tampilan → Efek kaca.
enum GlassPreference { auto, full, lite, off }

/// Menyimpan pilihan pengguna dan tingkat dari pengawas frame.
class GlassController extends ChangeNotifier {
  GlassController({
    GlassPreference preference = GlassPreference.auto,
    GlassTier autoTier = GlassTier.full,
    this.persist = false,
  }) : _preference = preference,
       _autoTier = autoTier;

  /// Dibaca dari preferensi (`glass_preference`, bawaan otomatis) dan
  /// tingkat pengawas frame (`glass_tier_auto`). Tingkat otomatis di-reset
  /// sekali saat versi aplikasi berubah (LIQUID_GLASS.md §7).
  factory GlassController.load() => GlassController(
    preference: SharedPreferencesService.getGlassPreference(),
    autoTier:
        GlassTier.values
            .where(
              (tier) =>
                  tier.name ==
                  SharedPreferencesService.getGlassAutoTier(appVersion),
            )
            .firstOrNull ??
        GlassTier.full,
    persist: true,
  );

  /// Simpan tingkat otomatis ke preferensi (produksi); tes tidak.
  final bool persist;

  GlassPreference _preference;
  GlassPreference get preference => _preference;

  GlassTier _autoTier;

  /// Tingkat yang dipilih pengawas frame saat preferensi Otomatis.
  GlassTier get autoTier => _autoTier;

  Future<void> setPreference(GlassPreference value) async {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
    await SharedPreferencesService.setGlassPreference(value);
  }

  /// Dipanggil pengawas frame. Hanya bisa turun di sesi yang sama (§7).
  void lowerAutoTier(GlassTier tier) {
    if (tier.index <= _autoTier.index) return;
    _autoTier = tier;
    notifyListeners();
    if (persist) {
      unawaited(
        SharedPreferencesService.setGlassAutoTier(tier.name, appVersion),
      );
    }
  }
}

/// Menyediakan [GlassController] untuk semua rute (dipasang di atas
/// Navigator, lewat `MaterialApp.builder`).
class GlassScope extends InheritedNotifier<GlassController> {
  const GlassScope({
    super.key,
    required GlassController controller,
    required super.child,
  }) : super(notifier: controller);

  static GlassController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.notifier;

  /// Tingkat efektif untuk kaca di [context]:
  /// - palet kontras tinggi atau kontras tinggi sistem → padat;
  /// - "Efek kaca: Mati" → padat;
  /// - "Kurangi gerak" sistem → paling tinggi ringan;
  /// - selain itu pilihan pengguna, atau tingkat pengawas frame bila Otomatis.
  static GlassTier tierOf(BuildContext context) {
    final controller = maybeOf(context);
    final tokens = Theme.of(context).extension<GlassTokens>();
    if (tokens?.forcesSolid ?? false) return GlassTier.solid;
    if (MediaQuery.highContrastOf(context)) return GlassTier.solid;
    var tier = switch (controller?.preference ?? GlassPreference.auto) {
      GlassPreference.auto => controller?.autoTier ?? GlassTier.full,
      GlassPreference.full => GlassTier.full,
      GlassPreference.lite => GlassTier.lite,
      GlassPreference.off => GlassTier.solid,
    };
    if (MediaQuery.disableAnimationsOf(context) && tier == GlassTier.full) {
      tier = GlassTier.lite;
    }
    return tier;
  }
}
