import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

// Ornamen v3 untuk splash dan onboarding (docs/design/v3/DESIGN.md §4b, §5).
// Ukuran relatif diambil dari HTML acuan di docs/design/v3/html/.

/// Berkas logo. Logo selalu utuh lewat [Image.asset]; versi gelap dipilih
/// lewat berkasnya sendiri, tidak lewat filter warna (DESIGN v3 §2).
abstract final class BrandAssets {
  static const logo = 'assets/brand/logo_utama.png';
  static const logoDark = 'assets/brand/logo_utama_gelap.png';
  static const secondary = 'assets/brand/logo_sekunder.png';

  /// Rasio tinggi/lebar logo utama (762 × 766 piksel).
  static const logoAspect = 766 / 762;

  static String logoFor(SacredTokens tokens) => tokens.isDark ? logoDark : logo;
}

/// Logo utama selebar [width], tinggi mengikuti rasio berkasnya.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.width, this.semanticLabel});

  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Image.asset(
      BrandAssets.logoFor(tokens),
      width: width,
      height: width * BrandAssets.logoAspect,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      gaplessPlayback: true,
    );
  }
}

/// Bintang delapan sudut: dua persegi bersudut bulat (satu diputar 45°) dan
/// lingkaran tipis. Sisi persegi 0.62, radius sudut 0.05, dan lingkaran 0.24
/// dari sisi kanvas (V3-Splash.html: 186/300, 15/300, 72/300).
class EightPointStar extends StatelessWidget {
  const EightPointStar({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = .8,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StarPainter(color: color, strokeWidth: strokeWidth),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final square = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: side * .62, height: side * .62),
      Radius.circular(side * .05),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas
      ..drawRRect(square, line)
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(math.pi / 4)
      ..translate(-center.dx, -center.dy)
      ..drawRRect(square, line)
      ..restore()
      ..drawCircle(
        center,
        side * .24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * .6
          ..color = color.withValues(alpha: color.a * .55),
      );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// Pola geometri emas v3: petak 56 berisi dua persegi (0.6 petak, satu
/// diputar 45°) dan garis pendek di tengah tiap sisi.
class BrandPattern extends StatelessWidget {
  const BrandPattern({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _PatternPainter(color), size: Size.infinite),
  );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter(this.color);

  final Color color;
  static const _tile = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = color;
    const half = _tile / 2;
    const inset = _tile * .2;
    const tick = 4.3;
    const square = Rect.fromLTRB(inset, inset, _tile - inset, _tile - inset);
    final cell = Path()
      ..addRect(square)
      ..moveTo(0, half)
      ..lineTo(tick, half)
      ..moveTo(_tile - tick, half)
      ..lineTo(_tile, half)
      ..moveTo(half, 0)
      ..lineTo(half, tick)
      ..moveTo(half, _tile - tick)
      ..lineTo(half, _tile);
    final turn = Matrix4.identity()
      ..translateByDouble(half, half, 0, 1)
      ..rotateZ(math.pi / 4)
      ..translateByDouble(-half, -half, 0, 1);
    final diamond = (Path()..addRect(square)).transform(turn.storage);
    for (var y = 0.0; y < size.height; y += _tile) {
      for (var x = 0.0; x < size.width; x += _tile) {
        final offset = Offset(x, y);
        canvas
          ..drawPath(cell.shift(offset), line)
          ..drawPath(diamond.shift(offset), line);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.color != color;
}

/// Pola yang memudar ke bawah (onboarding: hanya [height] teratas).
class FadingPattern extends StatelessWidget {
  const FadingPattern({super.key, required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF000000), Color(0x00000000)],
      ).createShader(bounds),
      child: BrandPattern(color: color),
    ),
  );
}

/// Gradien radial berbentuk elips seperti CSS
/// `radial-gradient(rx ry at cx cy, inner 0%, outer stop)`.
///
/// [center] dan [radii] dalam pecahan lebar/tinggi kanvas. Di luar [stop]
/// warnanya [outer] (bawaan: [inner] transparan).
class EllipseGlow extends StatelessWidget {
  const EllipseGlow({
    super.key,
    required this.inner,
    required this.center,
    required this.radii,
    required this.stop,
    this.outer,
  });

  final Color inner;
  final Offset center;
  final Offset radii;
  final double stop;
  final Color? outer;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _EllipsePainter(
      inner: inner,
      outer: outer ?? inner.withValues(alpha: 0),
      center: center,
      radii: radii,
      stop: stop,
    ),
  );
}

class _EllipsePainter extends CustomPainter {
  const _EllipsePainter({
    required this.inner,
    required this.outer,
    required this.center,
    required this.radii,
    required this.stop,
  });

  final Color inner;
  final Color outer;
  final Offset center;
  final Offset radii;
  final double stop;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(center.dx * size.width, center.dy * size.height);
    final rx = radii.dx * size.width;
    final ry = radii.dy * size.height;
    if (rx <= 0 || ry <= 0) return;
    // Gradien lingkaran berjari-jari rx, lalu diregangkan menjadi elips.
    final matrix = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(1, ry / rx, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    final shader = ui.Gradient.radial(
      c,
      rx,
      [inner, outer],
      [0, stop],
      TileMode.clamp,
      Float64List.fromList(matrix.storage),
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_EllipsePainter old) =>
      old.inner != inner ||
      old.outer != outer ||
      old.center != center ||
      old.radii != radii ||
      old.stop != stop;
}

/// Cahaya bundar di dalam kotak [size]. CSS `radial-gradient(circle, …)`
/// mengukur ke sudut terjauh, jadi jari-jari efektifnya `size/2 · √2 · stop`.
class RoundGlow extends StatelessWidget {
  const RoundGlow({
    super.key,
    required this.size,
    required this.color,
    required this.stop,
  });

  final double size;
  final Color color;
  final double stop;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            // Jari-jari RadialGradient relatif terhadap setengah sisi kotak.
            radius: math.sqrt2 * stop / 2,
          ),
        ),
      ),
    ),
  );
}
