import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';

/// Pembungkus lama; semua kaca sekarang lewat [LiquidGlass]
/// (docs/design/v4-liquid-glass/LIQUID_GLASS.md §3).
///
/// `tint` dan `borderColor` diabaikan: warna kaca ditentukan `GlassTokens`
/// per palet supaya kontras teks di atasnya tetap terjamin (§5).
@Deprecated('Pakai LiquidGlass dari lib/app/glass/liquid_glass.dart.')
class GlassSurface extends StatelessWidget {
  @Deprecated('Pakai LiquidGlass dari lib/app/glass/liquid_glass.dart.')
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
  final bool shadowless;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    borderRadius: borderRadius,
    padding: padding,
    shadow: !shadowless,
    child: child,
  );
}
