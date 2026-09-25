import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Matriks 4x5 untuk `ColorFilter.matrix` (LIQUID_GLASS.md §3, rumus
/// vibrancy). Backdrop dijenuhkan dengan [saturation], lalu rentang terangnya
/// ditekan ke [toward] sehingga hanya [keep] bagian backdrop yang tersisa.
/// Kolom translasi dalam skala 0..255, sesuai dokumentasi `ColorFilter.matrix`.
List<double> glassVibrancyMatrix({
  required double saturation,
  required double keep,
  required Color toward,
}) {
  const lr = .2126, lg = .7152, lb = .0722; // bobot luminans Rec.709
  final s = saturation;
  final sat = [
    [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
  ];
  final t = [toward.r * 255, toward.g * 255, toward.b * 255];
  return [
    for (var i = 0; i < 3; i++) ...[
      for (var j = 0; j < 3; j++) keep * sat[i][j],
      0,
      (1 - keep) * t[i],
    ],
    0,
    0,
    0,
    1,
    0,
  ];
}

final _filters = <GlassSpec, ui.ImageFilter>{};

/// Filter L1: blur lalu vibrancy. Disimpan per [GlassSpec] supaya objek
/// filternya sama antar-build dan lapisan backdrop tidak dibuat ulang.
ui.ImageFilter glassFilter(GlassSpec spec) => _filters.putIfAbsent(
  spec,
  () => ui.ImageFilter.compose(
    outer: ui.ColorFilter.matrix(
      glassVibrancyMatrix(
        saturation: spec.saturation,
        keep: spec.keep,
        toward: spec.toward,
      ),
    ),
    inner: ui.ImageFilter.blur(
      sigmaX: spec.sigma,
      sigmaY: spec.sigma,
      tileMode: TileMode.mirror,
    ),
  ),
);

/// Kaca v4 dengan enam lapis (LIQUID_GLASS.md §3). Hanya untuk bagian yang
/// mengambang: tab bar, nav pembaca, mini player, tombol bulat, kepala sheet.
/// Jangan dipakai untuk isi yang dibaca atau item di dalam daftar.
///
/// L0 bayangan di luar klip, L1 backdrop blur + vibrancy, L2 tint, L3 kilau,
/// L4 tepi bergradien, L5 sorot dalam. Tingkat ringan dan padat hanya
/// mengubah angka; bentuk dan ukurannya tetap.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.size = GlassSize.bar,
    this.padding,
    this.interactive = false,
    this.sheenShift,
    this.shadow = true,
    this.tier,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassSize size;
  final EdgeInsetsGeometry? padding;

  /// Kilau boleh bergeser mengikuti interaksi (mis. lensa tab).
  final bool interactive;

  /// Posisi kilau -1..1; dipakai bila [interactive]. Pergeseran maksimal 8%
  /// lebar (§6). Hanya berubah saat ada interaksi, tidak tiap frame.
  final ValueListenable<double>? sheenShift;

  /// L0. Matikan untuk bilah yang menempel di tepi layar.
  final bool shadow;

  /// Tingkat tetap untuk pratinjau (Saya → Efek kaca). Bawaannya mengikuti
  /// [GlassScope]. Palet kontras tinggi tetap selalu padat.
  final GlassTier? tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sacred =
        theme.extension<SacredTokens>() ??
        (theme.brightness == Brightness.dark
            ? SacredTokens.dark
            : SacredTokens.light);
    final glass = GlassTokens.of(context);
    final tier = glass.solidOnly
        ? GlassTier.solid
        : this.tier ?? GlassScope.tierOf(context);
    final spec = glass.spec(size, tier);
    final moving = interactive && tier == GlassTier.full;

    Widget content = CustomPaint(
      painter: _GlassFillPainter(
        radius: borderRadius,
        tint: spec.tint,
        sheen: glass.sheenTop,
        shift: moving ? sheenShift : null,
      ),
      // Ripple Material tidak dipakai di atas kaca (§6); sorot tekan tetap.
      child: Theme(
        data: theme.copyWith(splashFactory: NoSplash.splashFactory),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    content = Stack(
      // Isi mengikuti batas yang diberikan induk, bukan batas longgar Stack.
      fit: StackFit.passthrough,
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GlassEdgePainter(
                  radius: borderRadius,
                  rimStart: glass.rimStart,
                  rimEnd: glass.rimEnd,
                  rimWidth: glass.rimWidth,
                  highlight: glass.innerHighlight,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return CustomPaint(
      painter: shadow
          ? _GlassShadowPainter(
              radius: borderRadius,
              shadows: sacred.floatShadows,
            )
          : null,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          filter: glassFilter(spec),
          // Padat: filter dimatikan, bukan dicabut, supaya pohon layer tetap
          // sama saat tingkat berganti.
          enabled: tier != GlassTier.solid && spec.sigma > 0,
          child: content,
        ),
      ),
    );
  }
}

/// L0. Bayangan digambar di luar bentuk kaca saja. Kalau ikut tergambar di
/// bawahnya, backdrop ikut menangkap bayangan dan kaca tampak kusam.
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.radius, required this.shadows});

  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        shadow.blurRadius * 2 + shadow.spreadRadius + shadow.offset.distance,
      );
    }
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(reach))
          ..addRRect(shape),
      );
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.radius != radius || !_sameShadows(old.shadows, shadows);

  static bool _sameShadows(List<BoxShadow> a, List<BoxShadow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// L2 tint dan L3 kilau, di bawah isi.
class _GlassFillPainter extends CustomPainter {
  _GlassFillPainter({
    required this.radius,
    required this.tint,
    required this.sheen,
    this.shift,
  }) : super(repaint: shift);

  final BorderRadius radius;
  final Color tint;
  final Color sheen;
  final ValueListenable<double>? shift;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = radius.toRRect(Offset.zero & size);
    canvas.drawRRect(shape, Paint()..color = tint);
    if (sheen.a == 0) return;
    // Kilau dari tepi atas, habis di 55% tinggi. Bentuknya elips lebar yang
    // berpusat di tepi atas: di tengah turun lurus atas → bawah, di ujung
    // sedikit melandai, sehingga permukaan terasa melengkung. Pusatnya
    // bergeser maksimal 8% lebar mengikuti interaksi (§6).
    if (size.isEmpty) return;
    final dx = (shift?.value ?? 0).clamp(-1.0, 1.0) * size.width * .08;
    final center = Offset(size.width / 2 + dx, 0);
    final ry = size.height * .55;
    final rx = math.max(size.width * .75, ry);
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(rx / ry, 1, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          ry,
          [sheen, sheen.withValues(alpha: 0)],
          null,
          TileMode.clamp,
          matrix.storage,
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassFillPainter old) =>
      old.radius != radius ||
      old.tint != tint ||
      old.sheen != sheen ||
      old.shift != shift;
}

/// L4 tepi bergradien dan L5 sorot dalam, di atas isi.
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.radius,
    required this.rimStart,
    required this.rimEnd,
    required this.rimWidth,
    required this.highlight,
  });

  final BorderRadius radius;
  final Color rimStart;
  final Color rimEnd;
  final double rimWidth;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = radius.toRRect(bounds);
    canvas.drawRRect(
      shape.deflate(rimWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [
          rimStart,
          rimEnd,
        ]),
    );
    if (highlight.a == 0) return;
    // Garis 1 px tepat di bawah tepi atas, memudar sebelum lengkung sudut
    // selesai, sehingga kaca terasa tebal.
    final fade = math.min(math.max(radius.topLeft.y, 8.0), size.height / 2);
    canvas
      ..save()
      ..clipRRect(shape);
    canvas.drawRRect(
      shape.deflate(rimWidth).shift(const Offset(0, 1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, fade), [
          highlight,
          highlight.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius ||
      old.rimStart != rimStart ||
      old.rimEnd != rimEnd ||
      old.rimWidth != rimWidth ||
      old.highlight != highlight;
}
