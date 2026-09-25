import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Tingkat kualitas kaca (LIQUID_GLASS.md §4, "Tingkat kualitas").
///
/// Urutannya dari paling mahal ke paling murah; pengawas frame hanya boleh
/// bergerak ke kanan.
enum GlassTier { full, lite, solid }

/// Pilihan pengguna di Saya → Tampilan → Efek kaca. Flutter tidak memberi
/// sinyal "Kurangi transparansi" iOS, jadi pilihan ini penggantinya.
enum GlassPreference {
  auto('Otomatis'),
  full('Penuh'),
  lite('Ringan'),
  off('Mati');

  const GlassPreference(this.label);

  final String label;
}

/// Tingkat efektif dari semua sumber. Urutan: kontras tinggi (palet atau
/// sistem) dan "Mati" selalu padat; "Kurangi gerak" paling tinggi ringan;
/// "Otomatis" mengikuti pengawas frame.
GlassTier resolveGlassTier({
  required GlassPreference preference,
  required GlassTier autoTier,
  required bool solidPalette,
  required bool highContrast,
  required bool disableAnimations,
}) {
  if (solidPalette || highContrast) return GlassTier.solid;
  final chosen = switch (preference) {
    GlassPreference.auto => autoTier,
    GlassPreference.full => GlassTier.full,
    GlassPreference.lite => GlassTier.lite,
    GlassPreference.off => GlassTier.solid,
  };
  if (disableAnimations && chosen == GlassTier.full) return GlassTier.lite;
  return chosen;
}

/// Menyimpan pilihan pengguna dan tingkat hasil pengawas frame.
class GlassController extends ChangeNotifier {
  GlassPreference _preference = GlassPreference.auto;
  GlassPreference get preference => _preference;

  GlassTier _autoTier = GlassTier.full;

  /// Tingkat yang dipilih pengawas frame untuk mode "Otomatis".
  GlassTier get autoTier => _autoTier;

  void load() {
    _preference = SharedPreferencesService.getGlassPreference();
    _autoTier = SharedPreferencesService.getGlassAutoTier();
  }

  Future<void> setPreference(GlassPreference value) async {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
    await SharedPreferencesService.setGlassPreference(value);
  }

  /// Dipanggil pengawas frame. Tingkat hanya turun (§7); permintaan naik
  /// diabaikan supaya tampilan tidak bolak-balik di sesi yang sama.
  Future<void> setAutoTier(GlassTier value) async {
    if (value.index <= _autoTier.index) return;
    _autoTier = value;
    notifyListeners();
    await SharedPreferencesService.setGlassAutoTier(value);
  }
}

/// Menyediakan [GlassController] ke seluruh aplikasi. Dipasang di atas
/// Navigator (lewat `MaterialApp.builder`) supaya semua rute melihatnya.
class GlassScope extends InheritedNotifier<GlassController> {
  const GlassScope({
    super.key,
    required GlassController controller,
    required super.child,
  }) : super(notifier: controller);

  static GlassController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.notifier;

  /// Tingkat efektif untuk kaca di [context]. Tanpa [GlassScope] (mis. di
  /// tes widget) dianggap "Otomatis" dengan tingkat penuh.
  static GlassTier tierOf(BuildContext context) {
    final controller = maybeOf(context);
    return resolveGlassTier(
      preference: controller?.preference ?? GlassPreference.auto,
      autoTier: controller?.autoTier ?? GlassTier.full,
      solidPalette: GlassTokens.of(context).solidOnly,
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
      disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }
}
