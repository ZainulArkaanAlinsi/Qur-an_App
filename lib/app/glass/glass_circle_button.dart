import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_motion.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

/// Tombol bulat mengambang berkaca (LIQUID_GLASS.md §2): kembali, Aa, atau
/// putar di atas hero. [LiquidGlass] ukuran kecil, diameter 40–44, target
/// sentuh minimal 44. Tanpa ripple; saat ditekan mengecil ke 0.94.
class GlassCircleButton extends StatefulWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.diameter = 44,
    this.iconSize = 20,
    this.filled = false,
    this.strokeWidth = 1.9,
  }) : assert(diameter >= 40 && diameter <= 44);

  final List<String> icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double diameter;
  final double iconSize;

  /// Ikon isi (mis. jeda saat sedang diputar).
  final bool filled;
  final double strokeWidth;

  @override
  State<GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<GlassCircleButton> {
  bool _pressed = false;

  void _press(bool value) {
    if (widget.onTap == null || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final d = widget.diameter;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          child: SizedBox.square(
            dimension: math.max(44, d),
            child: Center(
              child: AnimatedScale(
                scale: _pressed && !reduced ? GlassMotion.pressScale : 1,
                duration: GlassMotion.press,
                curve: Curves.easeOut,
                child: LiquidGlass(
                  size: GlassSize.small,
                  borderRadius: BorderRadius.circular(d / 2),
                  child: SizedBox.square(
                    dimension: d,
                    child: Center(
                      child: LineIcon(
                        widget.icon,
                        color: tokens.ink,
                        size: widget.iconSize,
                        filled: widget.filled,
                        strokeWidth: widget.strokeWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
