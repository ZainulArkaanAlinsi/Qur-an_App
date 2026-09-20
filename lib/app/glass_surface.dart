import 'dart:ui';

import 'package:flutter/material.dart';

/// A deliberately small, clipped blur surface for navigation and compact cards.
/// Large scrolling content uses tonal containers instead to protect scroll FPS.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = tint ??
        (dark
            ? const Color(0xFF173126).withValues(alpha: .72)
            : Colors.white.withValues(alpha: .62));
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .10)
                  : Colors.white.withValues(alpha: .72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .16 : .06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
