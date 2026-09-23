import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Satu hari pada heatmap istiqamah.
@immutable
class HeatCell {
  const HeatCell({
    required this.date,
    required this.seconds,
    required this.targetSeconds,
    this.isToday = false,
    this.isFuture = false,
  });

  final DateTime date;
  final int seconds;
  final int targetSeconds;
  final bool isToday;

  /// Hari yang belum datang dibiarkan kosong, bukan ditandai gagal.
  final bool isFuture;

  /// 0 = belum membaca, 3 = target tercapai. Tingkatannya dihitung terhadap
  /// target hari itu, bukan angka tetap, karena target bisa berubah.
  int get level {
    if (seconds <= 0) return 0;
    if (targetSeconds <= 0 || seconds >= targetSeconds) return 3;
    return seconds / targetSeconds >= 2 / 3 ? 2 : 1;
  }
}

/// Heatmap istiqamah (Progres.html): tujuh kolom, sel tinggi 24 dengan radius
/// 7 dan jarak 5. Hari ini bergaris putus-putus emas.
class SacredHeatmap extends StatelessWidget {
  const SacredHeatmap({
    super.key,
    required this.cells,
    this.columns = 7,
    this.cellHeight = 24,
    this.gap = 5,
  });

  /// Urut dari hari paling lama ke hari terbaru.
  final List<HeatCell> cells;
  final int columns;
  final double cellHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            // Sel yang sangat lebar terlihat aneh pada rentang pendek; ikuti
            // proporsi mockup dengan membatasi tingginya.
            final height = math.min(cellHeight, width);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final cell in cells)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _Cell(cell: cell),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Sedikit',
              style: SacredText.legend.copyWith(color: tokens.sec),
            ),
            const SizedBox(width: 6),
            for (final level in tokens.heatmap)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: level,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 2),
            Text(
              'Banyak',
              style: SacredText.legend.copyWith(color: tokens.sec),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final HeatCell cell;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final minutes = (cell.seconds / 60).floor();
    final label = cell.isFuture
        ? 'belum datang'
        : minutes == 0
        ? 'belum membaca'
        : '$minutes menit';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${cell.date.day}/${cell.date.month}: $label',
      child: CustomPaint(
        painter: _CellPainter(
          color: cell.isFuture
              ? const Color(0x00000000)
              : tokens.heatmap[cell.level],
          ring: cell.isFuture ? tokens.sep : null,
          dashed: cell.isToday ? tokens.gold : null,
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter({required this.color, this.ring, this.dashed});

  final Color color;

  /// Garis tipis untuk hari yang belum datang.
  final Color? ring;

  /// Garis putus-putus emas untuk hari ini.
  final Color? dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    if (color.a > 0) canvas.drawRRect(rect, Paint()..color = color);
    if (ring != null) {
      canvas.drawRRect(
        rect.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ring!,
      );
    }
    if (dashed != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = dashed!;
      final path = Path()..addRRect(rect.deflate(1));
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 3, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += 6;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.color != color || old.ring != ring || old.dashed != dashed;
}
