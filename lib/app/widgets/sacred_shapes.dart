import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Lengkung mihrab, bentuk khas desain (DESIGN_SPEC §5).
///
/// [startRatio] menentukan tinggi sisi lurus sebelum lengkung dimulai;
/// bawaannya mengikuti rumus `min(h*0.42, w*0.46)`.
class MihrabClipper extends CustomClipper<Path> {
  const MihrabClipper({this.radius = 18, this.startRatio});

  final double radius;
  final double? startRatio;

  static Path pathFor(Size size, {double radius = 18, double? startRatio}) {
    final w = size.width;
    final h = size.height;
    final s = startRatio ?? math.min(h * 0.42, w * 0.46);
    final r = math.min(radius, math.min(w, h) / 2);
    return Path()
      ..moveTo(0, h - r)
      ..lineTo(0, s)
      ..cubicTo(0, s * 0.42, w * 0.30, s * 0.16, w / 2, 0)
      ..cubicTo(w * 0.70, s * 0.16, w, s * 0.42, w, s)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
  }

  @override
  Path getClip(Size size) =>
      pathFor(size, radius: radius, startRatio: startRatio);

  @override
  bool shouldReclip(MihrabClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.startRatio != startRatio;
}

/// Sampul/bingkai mihrab: isi di-clip mengikuti lengkung, dengan garis emas
/// tipis di dalamnya.
class MihrabFrame extends StatelessWidget {
  const MihrabFrame({
    super.key,
    required this.child,
    this.background,
    this.lineColor,
    this.radius = 18,
    this.inset = 8,
  });

  final Widget child;
  final Color? background;
  final Color? lineColor;
  final double radius;

  /// Jarak garis emas dari tepi (6–10 px pada desain).
  final double inset;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return CustomPaint(
      foregroundPainter: _MihrabLinePainter(
        color: lineColor ?? tokens.gold.withValues(alpha: .8),
        radius: radius,
        inset: inset,
      ),
      child: ClipPath(
        clipper: MihrabClipper(radius: radius),
        child: ColoredBox(
          color: background ?? tokens.art,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MihrabLinePainter extends CustomPainter {
  const _MihrabLinePainter({
    required this.color,
    required this.radius,
    required this.inset,
  });

  final Color color;
  final double radius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= inset * 2 || size.height <= inset * 2) return;
    final inner = Size(size.width - inset * 2, size.height - inset * 2);
    final path = MihrabClipper.pathFor(
      inner,
      radius: radius * .8,
    ).shift(Offset(inset, inset));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MihrabLinePainter old) =>
      old.color != color || old.radius != radius || old.inset != inset;
}

/// Bintang segi delapan: dua persegi diputar 0° dan 45° plus lingkaran
/// samar. Dipakai untuk nomor surah dan penanda akhir ayat.
class RosetteBadge extends StatelessWidget {
  const RosetteBadge({
    super.key,
    required this.label,
    this.size = 34,
    this.color,
    this.textColor,
    this.textStyle,
    this.semanticsLabel,
    this.outlined = false,
  });

  /// Penanda akhir ayat memakai angka Arab-Indik dan warna emas.
  ///
  /// Angka Arab-Indik tidak ada di font Latin yang dibundel (sudah dipangkas),
  /// jadi penanda ini wajib memakai font Al-Qur'an.
  factory RosetteBadge.ayah(
    int ayah, {
    Key? key,
    double size = 32,
    Color? color,
    Color? textColor,
  }) => RosetteBadge(
    key: key,
    label: arabicNumerals(ayah),
    size: size,
    color: color,
    textColor: textColor,
    textStyle: const TextStyle(fontFamily: SacredText.quran),
    semanticsLabel: 'Ayat $ayah',
  );

  final String label;
  final double size;
  final Color? color;
  final Color? textColor;
  final TextStyle? textStyle;
  final String? semanticsLabel;

  /// Versi garis, seperti nomor surah pada daftar Qur'an di mockup.
  final bool outlined;

  /// 123 -> ١٢٣
  static String arabicNumerals(int value) => value
      .toString()
      .split('')
      .map((digit) => String.fromCharCode(0x0660 + int.parse(digit)))
      .join();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final shape = color ?? tokens.gold;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RosettePainter(shape, outlined: outlined),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: (textStyle ?? SacredText.footnote).copyWith(
                fontSize: size * .37,
                color: textColor ?? tokens.goldText,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  const _RosettePainter(this.color, {this.outlined = false});

  final Color color;
  final bool outlined;

  @override
  void paint(Canvas canvas, Size size) {
    // Ukuran relatif mengikuti mockup: persegi 62% sisi, lingkaran r 24%.
    final side = size.width * .62;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: side, height: side),
      Radius.circular(size.width * .05),
    );
    final paint = outlined
        ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * .038
            ..color = color)
        : (Paint()..color = color.withValues(alpha: .28));

    canvas.drawCircle(
      center,
      size.width * .24,
      outlined
          ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * .023
              ..color = color.withValues(alpha: .55))
          : (Paint()..color = color.withValues(alpha: .55)),
    );
    for (final turns in [0.0, 0.125]) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(turns * 2 * math.pi)
        ..translate(-center.dx, -center.dy)
        ..drawRRect(rect, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.color != color || old.outlined != outlined;
}

/// Pola bintang delapan sudut yang diulang. Digambar dengan painter di dalam
/// [RepaintBoundary] supaya tidak menggambar ulang saat halaman bergulir.
class GeometricPattern extends StatelessWidget {
  const GeometricPattern({
    super.key,
    this.tile = 48,
    this.opacity = .12,
    this.color,
  });

  final double tile;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PatternPainter(
          color: (color ?? tokens.artInk).withValues(alpha: opacity),
          tile: tile.clamp(40, 56),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.color, required this.tile});

  final Color color;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = color;
    final radius = tile * .34;
    for (var y = tile / 2; y < size.height + tile; y += tile) {
      for (var x = tile / 2; x < size.width + tile; x += tile) {
        final center = Offset(x, y);
        for (final turns in [0.0, 0.125]) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final angle = turns * 2 * math.pi + i * math.pi / 2;
            final point = Offset(
              center.dx + radius * math.cos(angle),
              center.dy + radius * math.sin(angle),
            );
            if (i == 0) {
              path.moveTo(point.dx, point.dy);
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
          canvas.drawPath(path..close(), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.color != color || old.tile != tile;
}

/// Strip/kartu berlatar langit sesuai periode waktu salat.
class SkyStrip extends StatelessWidget {
  const SkyStrip({
    super.key,
    required this.period,
    required this.child,
    this.height = 64,
    this.radius = 20,
    this.showStars = false,
  });

  final SkyPeriod period;
  final Widget child;
  final double height;
  final double radius;

  /// Bintang kecil untuk periode malam.
  final bool showStars;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(gradient: period.gradient),
        child: Stack(
          children: [
            if (showStars || period == SkyPeriod.night)
              const Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _Stars())),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends CustomPainter {
  const _Stars();

  @override
  void paint(Canvas canvas, Size size) {
    // Posisi tetap (bukan acak) agar tidak berubah tiap frame.
    const points = [
      Offset(.12, .30),
      Offset(.28, .62),
      Offset(.44, .22),
      Offset(.61, .54),
      Offset(.76, .28),
      Offset(.89, .62),
    ];
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .7);
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        1.1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stars oldDelegate) => false;
}
