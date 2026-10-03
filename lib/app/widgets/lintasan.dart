import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Gaya [Lintasan]: di atas permukaan biasa, atau di atas kartu hijau.
enum LintasanStyle { onSurface, onHero }

/// Bahasa visual "Lintasan" (docs/design/v6/DESIGN.md §2): titik-titik
/// berjarak sama yang disambung garis, untuk semua yang bersifat urutan
/// (horizon salat, langkah sesi, pekan istiqamah).
///
/// - Garis sampai [progress] (0..1 sepanjang lintasan) memakai warna "sudah";
///   sisanya warna "belum".
/// - Titik [current] (bila ada) diberi cincin emas + halo.
/// - [nowMarker]: titik "sekarang" di posisi [progress] (horizon salat).
///
/// Satu `CustomPainter` di dalam `RepaintBoundary`, tanpa animasi per frame.
/// Label (bila ada) ditaruh tepat di bawah tiap titik.
class Lintasan extends StatelessWidget {
  const Lintasan({
    super.key,
    required this.count,
    required this.progress,
    this.current,
    this.labels,
    this.style = LintasanStyle.onSurface,
    this.nowMarker = false,
    this.labelStyle,
    this.currentLabelStyle,
  }) : assert(count >= 2),
       assert(labels == null || labels.length == count);

  final int count;
  final double progress;
  final int? current;
  final List<String>? labels;
  final LintasanStyle style;
  final bool nowMarker;

  /// Gaya label biasa dan label titik [current]; bawaannya 11/700.
  final TextStyle? labelStyle;
  final TextStyle? currentLabelStyle;

  /// Tinggi area titik: cincin 16 + halo 4 di kedua sisi.
  static const trackHeight = 24.0;

  /// Jarak titik pertama/terakhir dari tepi, supaya cincin tidak terpotong.
  static const edge = 12.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final onHero = style == LintasanStyle.onHero;
    final colors = _LintasanColors(
      base: onHero ? tokens.onHero.withValues(alpha: .18) : tokens.surf2,
      done: onHero ? tokens.onHero : tokens.primaryText,
      ring: onHero ? tokens.goldLine : tokens.gold,
      halo: onHero ? tokens.goldLine.withValues(alpha: .28) : tokens.goldSoft,
      hollow: onHero ? tokens.heroA : tokens.surf,
      now: tokens.ink,
      nowHalo: tokens.surf,
    );
    final track = RepaintBoundary(
      child: CustomPaint(
        size: const Size(double.infinity, trackHeight),
        painter: _LintasanPainter(
          count: count,
          progress: progress.clamp(0.0, 1.0),
          current: current,
          nowMarker: nowMarker,
          colors: colors,
        ),
      ),
    );
    final names = labels;
    if (names == null) return track;
    final base =
        labelStyle ??
        SacredText.withWeight(
          SacredText.legend,
          700,
        ).copyWith(color: onHero ? tokens.onHeroSec : tokens.sec);
    final strong =
        currentLabelStyle ??
        SacredText.withWeight(
          base,
          800,
        ).copyWith(color: onHero ? tokens.onHero : tokens.ink);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        track,
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final positions = dotPositions(box.maxWidth, count);
            final slot = (box.maxWidth - 2 * edge) / (count - 1);
            return SizedBox(
              height: _labelHeight(context, base),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < count; i++)
                    Positioned(
                      // Label lebar satu jarak antartitik, berpusat di titik;
                      // label ujung digeser masuk supaya tidak keluar layar.
                      left: (positions[i] - slot / 2).clamp(
                        0.0,
                        box.maxWidth - slot,
                      ),
                      width: slot,
                      top: 0,
                      child: Text(
                        names[i],
                        maxLines: 1,
                        softWrap: false,
                        textAlign: i == 0
                            ? TextAlign.left
                            : i == count - 1
                            ? TextAlign.right
                            : TextAlign.center,
                        style: i == current ? strong : base,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static double _labelHeight(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final size = scaler.scale(style.fontSize ?? 11);
    return size * (style.height ?? 1.3) + 2;
  }

  /// Posisi x titik ke-i (jarak sama, [edge] dari kedua tepi).
  static List<double> dotPositions(double width, int count) {
    final span = width - 2 * edge;
    return [for (var i = 0; i < count; i++) edge + span * i / (count - 1)];
  }
}

@immutable
class _LintasanColors {
  const _LintasanColors({
    required this.base,
    required this.done,
    required this.ring,
    required this.halo,
    required this.hollow,
    required this.now,
    required this.nowHalo,
  });

  final Color base;
  final Color done;
  final Color ring;
  final Color halo;
  final Color hollow;
  final Color now;
  final Color nowHalo;

  @override
  bool operator ==(Object other) =>
      other is _LintasanColors &&
      other.base == base &&
      other.done == done &&
      other.ring == ring &&
      other.halo == halo &&
      other.hollow == hollow &&
      other.now == now &&
      other.nowHalo == nowHalo;

  @override
  int get hashCode => Object.hash(base, done, ring, halo, hollow, now, nowHalo);
}

class _LintasanPainter extends CustomPainter {
  _LintasanPainter({
    required this.count,
    required this.progress,
    required this.current,
    required this.nowMarker,
    required this.colors,
  });

  final int count;
  final double progress;
  final int? current;
  final bool nowMarker;
  final _LintasanColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = Lintasan.dotPositions(size.width, count);
    final y = size.height / 2;
    final reach = xs.first + (xs.last - xs.first) * progress;
    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(xs.first, y),
      Offset(xs.last, y),
      line..color = colors.base,
    );
    if (progress > 0) {
      canvas.drawLine(
        Offset(xs.first, y),
        Offset(reach, y),
        line..color = colors.done,
      );
    }
    for (var i = 0; i < count; i++) {
      final c = Offset(xs[i], y);
      final passed = xs[i] <= reach + .01;
      if (i == current) {
        // Cincin emas 16 + halo 4 (DESIGN v6 §2).
        canvas.drawCircle(c, 10, Paint()..color = colors.halo);
        canvas.drawCircle(c, 7, Paint()..color = colors.hollow);
        canvas.drawCircle(
          c,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = colors.ring,
        );
        continue;
      }
      if (passed) {
        canvas.drawCircle(c, 4, Paint()..color = colors.done);
      } else {
        canvas.drawCircle(c, 4, Paint()..color = colors.hollow);
        canvas.drawCircle(
          c,
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colors.base,
        );
      }
    }
    if (nowMarker) {
      final c = Offset(reach, y);
      canvas.drawCircle(c, 9, Paint()..color = colors.nowHalo);
      canvas.drawCircle(c, 6, Paint()..color = colors.now);
    }
  }

  @override
  bool shouldRepaint(_LintasanPainter old) =>
      old.count != count ||
      old.progress != progress ||
      old.current != current ||
      old.nowMarker != nowMarker ||
      old.colors != colors;
}
