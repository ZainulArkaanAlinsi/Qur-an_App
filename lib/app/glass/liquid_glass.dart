import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Satu-satunya permukaan kaca di aplikasi (LIQUID_GLASS.md §3).
///
/// Enam lapis, dari bawah ke atas:
/// - L0 bayangan, digambar hanya di luar bentuk supaya tidak menggelapkan kaca;
/// - L1 backdrop: `BackdropFilter.grouped` dengan vibrancy di atas blur;
/// - L2 tint; L3 kilau; L4 tepi bergradien; L5 sorot dalam.
///
/// Hanya untuk chrome yang mengambang (§2). Jangan dipakai di item daftar
/// atau di belakang teks ayat. Tingkat penuh/ringan/padat dibaca dari
/// [GlassScope.tierOf]; bentuk dan ukuran tidak berubah antar-tingkat.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.size = GlassSize.bar,
    this.padding,
    this.interactive = false,
    this.sheenOffset = 0,
    this.shadow = true,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassSize size;
  final EdgeInsetsGeometry? padding;

  /// Kilau (L3) boleh bergeser mengikuti [sheenOffset], mis. posisi lensa
  /// tab. Hanya di tingkat penuh; di ringan/padat kilau diam (§4).
  final bool interactive;

  /// -1..1; geseran kilau maksimal 8% lebar (§6).
  final double sheenOffset;

  /// L0. Matikan bila kaca menempel di tepi layar (mis. nav pembaca).
  final bool shadow;

  /// Pengganti tint token (L2), mis. lensa tab `primarySoft` 92%. Di tingkat
  /// ringan alfanya naik 10 poin dan di tingkat padat menjadi penuh, sama
  /// seperti tint token.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = theme.extension<GlassTokens>() ?? GlassTokens.light;
    final sacred = theme.extension<SacredTokens>();
    final tier = GlassScope.tierOf(context);
    final spec = GlassSpec.resolve(
      tint == null ? glass : glass.copyWith(tint: tint),
      size,
      tier,
    );
    final shift = interactive && tier == GlassTier.full
        ? sheenOffset.clamp(-1.0, 1.0) * .16
        : 0.0;
    final radius = borderRadius;

    return CustomPaint(
      painter: shadow && sacred != null
          ? _OutsideShadowPainter(radius, sacred.floatShadows)
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: glassFilter(spec),
          enabled: spec.blur,
          child: CustomPaint(
            painter: _FillPainter(
              tint: spec.tint,
              sheenTop: tier == GlassTier.solid
                  ? glass.sheenTop.withValues(alpha: 0)
                  : glass.sheenTop,
              shift: shift,
            ),
            child: Stack(
              children: [
                Padding(padding: padding ?? EdgeInsets.zero, child: child),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _RimPainter(
                          radius: radius,
                          start: glass.rimStart,
                          end: glass.rimEnd,
                          width: glass.rimWidth,
                          highlight: glass.innerHighlight,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// L0: bayangan di luar bentuk. Bagian di dalam bentuk dipotong supaya
/// backdrop yang diblur tidak ikut gelap.
class _OutsideShadowPainter extends CustomPainter {
  _OutsideShadowPainter(this.radius, this.shadows);

  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(160))
      ..addRRect(shape);
    canvas.save();
    canvas.clipPath(outside);
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.radius != radius || !_sameShadows(old.shadows, shadows);

  static bool _sameShadows(List<BoxShadow> a, List<BoxShadow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// L2 tint + L3 kilau atas (memudar di 55% tinggi).
class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.tint,
    required this.sheenTop,
    required this.shift,
  });

  final Color tint;
  final Color sheenTop;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = tint);
    if (sheenTop.a == 0) return;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(shift, -1),
          end: Alignment(-shift, .1),
          colors: [sheenTop, sheenTop.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.tint != tint || old.sheenTop != sheenTop || old.shift != shift;
}

/// L4 tepi bergradien kiri-atas → kanan-bawah + L5 sorot dalam di atas.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.radius,
    required this.start,
    required this.end,
    required this.width,
    required this.highlight,
  });

  final BorderRadius radius;
  final Color start;
  final Color end;
  final double width;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rim = radius.toRRect(rect).deflate(width / 2);
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ).createShader(rect),
    );
    if (highlight.a == 0 || size.height <= 0) return;
    final inner = rim.deflate(width / 2 + .5);
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [highlight, highlight.withValues(alpha: 0)],
          stops: [0, (14 / size.height).clamp(0.0, 1.0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius ||
      old.start != start ||
      old.end != end ||
      old.width != width ||
      old.highlight != highlight;
}
