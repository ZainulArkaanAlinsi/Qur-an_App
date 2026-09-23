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
  });

  final DateTime date;
  final int seconds;
  final int targetSeconds;
  final bool isToday;

  /// 0 = belum membaca, 3 = target tercapai. Tingkatannya dihitung terhadap
  /// target hari itu, bukan angka tetap, karena target bisa berubah.
  int get level {
    if (seconds <= 0) return 0;
    if (targetSeconds <= 0 || seconds >= targetSeconds) return 3;
    return seconds / targetSeconds >= 2 / 3 ? 2 : 1;
  }
}

/// Heatmap istiqamah: satu baris per pekan, hari ini diberi garis emas.
class SacredHeatmap extends StatelessWidget {
  const SacredHeatmap({
    super.key,
    required this.cells,
    this.columns = 7,
    this.cellSize = 22,
  });

  /// Urut dari hari paling lama ke hari terbaru.
  final List<HeatCell> cells;
  final int columns;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final rows = (cells.length / columns).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var column = 0; column < columns; column++)
                  if (row * columns + column < cells.length)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Cell(
                        cell: cells[row * columns + column],
                        size: cellSize,
                      ),
                    ),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Sedikit',
              style: SacredText.footnote.copyWith(
                color: tokens.sec,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            for (final level in tokens.heatmap)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: level,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tokens.sep),
                  ),
                ),
              ),
            const SizedBox(width: 2),
            Text(
              'Target tercapai',
              style: SacredText.footnote.copyWith(
                color: tokens.sec,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.size});

  final HeatCell cell;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final minutes = (cell.seconds / 60).floor();
    return Semantics(
      label:
          '${cell.date.day}/${cell.date.month}: '
          '${minutes == 0 ? 'belum membaca' : '$minutes menit'}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tokens.heatmap[cell.level],
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: cell.isToday ? tokens.gold : tokens.sep,
            width: cell.isToday ? 1.6 : 1,
          ),
        ),
      ),
    );
  }
}
