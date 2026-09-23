import 'package:flutter/material.dart';

/// Warna lencana ikon pada baris pengaturan dan baris belajar.
///
/// Nilai terangnya disalin dari `Pengaturan.html`. Sebelumnya konstanta ini
/// ditulis dua kali sebagai `const` di dua layar, sehingga warnanya tetap pekat
/// di mode gelap dan tidak pernah ikut tema. Di sini warnanya dicerahkan untuk
/// latar gelap supaya lencananya tidak jadi lubang gelap di tengah kartu.
enum ChipTone {
  translate(Color(0xFF2C6E8F)),
  gold(Color(0xFF9A7415)),
  green(Color(0xFF0E6A4C)),
  slate(Color(0xFF56635C)),
  terracotta(Color(0xFFB0533A));

  const ChipTone(this.light);

  /// Warna pada latar terang, persis seperti mockup.
  final Color light;

  /// Versi untuk latar gelap: rona yang sama, tapi lebih terang dan sedikit
  /// lebih lembut agar glif putih di atasnya tetap terbaca.
  Color get dark {
    final hsl = HSLColor.fromColor(light);
    return hsl
        .withLightness((hsl.lightness + .18).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * .85).clamp(0.0, 1.0))
        .toColor();
  }

  /// Warna yang berlaku untuk kecerahan tema saat ini.
  Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
