import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Pilihan warna aplikasi. Sepia untuk membaca lama di ruangan terang,
/// kontras tinggi untuk mata yang butuh pemisahan warna lebih tegas.
enum AppPalette {
  sacred('Hijau (bawaan)'),
  sepia('Sepia'),
  highContrast('Kontras tinggi');

  const AppPalette(this.label);

  final String label;
}

abstract final class SacredTheme {
  static const primary = Color(0xFF003527);
  static const primaryContainer = Color(0xFF064E3B);
  static const gold = Color(0xFFFED65B);
  static const ivory = Color(0xFFFCF9F8);
  static const ink = Color(0xFF1B1C1C);

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  /// Token desain untuk palet dan kecerahan tertentu.
  static SacredTokens tokensFor(AppPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (palette) {
      AppPalette.sacred => isDark ? SacredTokens.dark : SacredTokens.light,
      // Sepia adalah tema baca terang; versi gelapnya memakai token gelap.
      AppPalette.sepia => isDark ? SacredTokens.dark : SacredTokens.sepia,
      AppPalette.highContrast =>
        isDark ? SacredTokens.highContrastDark : SacredTokens.highContrastLight,
    };
  }

  static ThemeData themeFor(AppPalette palette, Brightness brightness) {
    final tokens = tokensFor(palette, brightness);
    final base = _theme(brightness).copyWith(extensions: [tokens]);
    final isDark = brightness == Brightness.dark;
    return switch (palette) {
      AppPalette.sacred => base,
      AppPalette.sepia => _recolor(
        base,
        surface: isDark ? const Color(0xFF221C14) : const Color(0xFFF4ECD8),
        card: isDark ? const Color(0xFF2C2419) : const Color(0xFFFBF4E4),
        ink: isDark ? const Color(0xFFEDE0C8) : const Color(0xFF3E3222),
        outline: isDark ? const Color(0xFF453A29) : const Color(0xFFDDCFB2),
      ),
      // Hitam/putih penuh: kontras teks terhadap latar mencapai 21:1.
      AppPalette.highContrast => _recolor(
        base,
        surface: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        card: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
        ink: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        outline: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF3A3A3A),
      ),
    };
  }

  /// Mengganti warna permukaan dan teks tanpa mengubah bentuk komponen,
  /// sehingga tata letak tetap sama di semua palet.
  static ThemeData _recolor(
    ThemeData base, {
    required Color surface,
    required Color card,
    required Color ink,
    required Color outline,
  }) {
    final scheme = base.colorScheme.copyWith(
      surface: surface,
      onSurface: ink,
      surfaceContainerLowest: card,
      outlineVariant: outline,
    );
    return base.copyWith(
      // `extensions` ikut terbawa dari `base`, jadi token tetap tersedia.
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        foregroundColor: ink,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: outline),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: card,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(fillColor: card),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: isDark ? const Color(0xFF8FD7B8) : primary,
      surface: isDark ? const Color(0xFF101C18) : ivory,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Tanpa ini komponen Material (tombol, daftar, dialog) tetap memakai
      // font bawaan sistem dan terlihat lepas dari desainnya.
      fontFamily: SacredText.ui,
      scaffoldBackgroundColor: scheme.surface,
      // Typography bawaan menuliskan nama font sistem secara eksplisit, yang
      // menimpa `fontFamily` di atas; jadi disetel ulang di sini.
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        fontFamily: SacredText.ui,
        bodyColor: isDark ? const Color(0xFFE7EEE9) : ink,
        displayColor: isDark ? const Color(0xFFE7EEE9) : ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF172720) : const Color(0xFFFFFEFC),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? const Color(0xFF2A4036) : const Color(0xFFE5E9E2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF172720) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: isDark
            ? const Color(0xFF13221B)
            : const Color(0xFFFFFEFC),
        indicatorColor: isDark
            ? const Color(0xFF275945)
            : const Color(0xFFDDEFE3),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
