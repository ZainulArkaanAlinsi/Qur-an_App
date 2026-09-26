import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';

/// Pembungkus lama. Semua kaca sekarang digambar oleh [LiquidGlass]
/// (docs/design/v4-liquid-glass/LIQUID_GLASS.md); kelas ini hanya meneruskan
/// supaya pemanggil lama tidak rusak.
///
/// [tint] dan [borderColor] diabaikan: warna kaca dan tepinya kini dari
/// `GlassTokens`, dan angkanya dikunci oleh tes kontras.
@Deprecated('Pakai LiquidGlass dari lib/app/glass/liquid_glass.dart.')
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.tint,
    this.borderColor,
    this.shadowless = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? tint;
  final Color? borderColor;

  /// Tanpa lapis bayangan L0.
  final bool shadowless;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    borderRadius: borderRadius,
    size: GlassSize.bar,
    padding: padding,
    shadow: !shadowless,
    child: child,
  );
}
