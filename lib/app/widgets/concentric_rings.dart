import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Isi satu cincin.
@immutable
class RingValue {
  const RingValue({required this.fill, required this.color});

  /// 0..1.
  final double fill;
  final Color color;
}

/// 1–3 cincin konsentris (docs/design/v6/DESIGN.md §5): stroke 10, jarak 4,
/// ujung bulat, jalur `surf2`. Isinya bertambah 600 ms sekali saat pertama
/// tampil, tidak berulang ketika layar dibangun ulang (§6).
class ConcentricRings extends StatelessWidget {
  const ConcentricRings({
    super.key,
    required this.rings,
    this.size = 108,
    this.stroke = 10,
    this.gap = 4,
  });

  /// Luar → dalam.
  final List<RingValue> rings;
  final double size;
  final double stroke;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final still = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingsPainter(
            rings: rings,
            progress: t,
            stroke: stroke,
            gap: gap,
            track: tokens.surf2,
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.rings,
    required this.progress,
    required this.stroke,
    required this.gap,
    required this.track,
  });

  final List<RingValue> rings;
  final double progress;
  final double stroke;
  final double gap;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    var radius = size.shortestSide / 2 - stroke / 2;
    for (final ring in rings) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, paint..color = track);
      final sweep = 2 * math.pi * ring.fill.clamp(0.0, 1.0) * progress;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          paint..color = ring.color,
        );
      }
      radius -= stroke + gap;
      if (radius <= stroke / 2) break;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.rings.length != rings.length ||
      [
        for (var i = 0; i < rings.length; i++)
          old.rings[i].fill != rings[i].fill ||
              old.rings[i].color != rings[i].color,
      ].any((changed) => changed);
}
