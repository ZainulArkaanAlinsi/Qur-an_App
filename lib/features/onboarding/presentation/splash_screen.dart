import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/onboarding/presentation/brand_art.dart';

/// Kurva gerak v3: `Cubic(0.22, 1, 0.36, 1)` (DESIGN v3 §4b), disebut EASE.
const brandEase = Cubic(0.22, 1, 0.36, 1);

/// Splash animasi (docs/design/v3/screens/16-splash.md, V3-Splash.png):
/// jembatan dari splash sistem ke Onboarding/Beranda.
///
/// Selesai setelah [ready] beres dan minimal [minDuration] berlalu, tetapi
/// tidak pernah lebih dari [maxDuration]: bila inisialisasi belum selesai,
/// aplikasi tetap lanjut dan datanya dimuat di layar berikutnya.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.ready,
    required this.onFinished,
    this.minDuration = const Duration(milliseconds: 1400),
    this.maxDuration = const Duration(milliseconds: 2500),
  });

  final Future<void> ready;
  final VoidCallback onFinished;
  final Duration minDuration;
  final Duration maxDuration;

  /// Lini waktu penuh: tagline selesai di 1300 ms.
  static const timeline = Duration(milliseconds: 1300);

  /// Mode kurangi gerak: hanya fade 200 ms.
  static const reducedFade = Duration(milliseconds: 200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  Timer? _minTimer;
  Timer? _maxTimer;
  bool _minElapsed = false;
  bool _ready = false;
  bool _finished = false;
  bool _started = false;
  bool _reduced = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(widget.minDuration, () {
      _minElapsed = true;
      _maybeFinish();
    });
    _maxTimer = Timer(widget.maxDuration, _finish);
    unawaited(
      widget.ready.catchError((Object _) {}).whenComplete(() {
        _ready = true;
        _maybeFinish();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _clock.duration = _reduced
        ? SplashScreen.reducedFade
        : SplashScreen.timeline;
    // Logo dimuat dulu supaya tidak berkedip; kalau lama, animasi tetap
    // berjalan (maksimal 300 ms menunggu).
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    void ignore(Object error, StackTrace? stack) {}
    unawaited(
      Future.wait([
            precacheImage(
              AssetImage(BrandAssets.logoFor(tokens)),
              context,
              onError: ignore,
            ),
            precacheImage(
              const AssetImage(BrandAssets.secondary),
              context,
              onError: ignore,
            ),
          ])
          .timeout(const Duration(milliseconds: 300))
          .catchError((Object _) => const <void>[])
          .whenComplete(_start),
    );
  }

  void _start() {
    if (_started || !mounted) return;
    _started = true;
    _clock.forward();
  }

  void _maybeFinish() {
    if (_minElapsed && _ready) _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _minTimer?.cancel();
    _maxTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _maxTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  /// Nilai 0..1 pada rentang [startMs, endMs] lini waktu, dengan EASE.
  double _phase(double startMs, double endMs) {
    final total = SplashScreen.timeline.inMilliseconds;
    return Interval(
      startMs / total,
      endMs / total,
      curve: brandEase,
    ).transform(_clock.value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final media = MediaQuery.of(context);
    final size = media.size;
    // Pusat logo di y=372 dari 844 (V3-Splash.html).
    final centerY = size.height * 372 / 844;
    final taglineBottom = math.max(54.0, media.padding.bottom + 20);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Semantics(
        label: 'MyQuran',
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            // Mode kurangi gerak: tanpa skala dan rotasi, semua hanya fade.
            final still = _reduced;
            final fade = brandEase.transform(_clock.value);
            final secondary = still ? fade : _phase(0, 260);
            final glowScale = still ? 1.0 : _phase(0, 900);
            final glowOpacity = still ? fade : _phase(0, 540);
            final star = still ? fade : _phase(0, 1100);
            final logo = still ? fade : _phase(120, 940);
            final tagline = still ? fade : _phase(715, 1300);
            return Stack(
              children: [
                // Pola emas 6% (× 0.9) yang memudar ke tepi.
                Positioned.fill(
                  child: BrandPattern(
                    color: tokens.gold.withValues(alpha: .054),
                  ),
                ),
                Positioned.fill(
                  child: EllipseGlow(
                    inner: tokens.bg.withValues(alpha: 0),
                    outer: tokens.bg,
                    center: const Offset(.5, .44),
                    radii: const Offset(.9, .55),
                    stop: .78,
                  ),
                ),
                _centered(
                  size: size,
                  centerY: centerY,
                  extent: 380,
                  child: Opacity(
                    opacity: glowOpacity,
                    child: Transform.scale(
                      scale: .55 + .45 * glowScale,
                      child: RoundGlow(
                        size: 380,
                        color: tokens.isDark
                            ? SacredGlow.splashDark
                            : SacredGlow.splashLight,
                        stop: .68,
                      ),
                    ),
                  ),
                ),
                _centered(
                  size: size,
                  centerY: centerY,
                  extent: 300,
                  child: Opacity(
                    opacity: .35 * star,
                    child: Transform.rotate(
                      angle: still ? 0 : -math.pi / 6 * (1 - star),
                      child: Transform.scale(
                        scale: still ? 1 : .9 + .1 * star,
                        child: EightPointStar(size: 300, color: tokens.gold),
                      ),
                    ),
                  ),
                ),
                _centered(
                  size: size,
                  centerY: centerY,
                  extent: 250,
                  height: 250 * BrandAssets.logoAspect,
                  child: Opacity(
                    opacity: logo,
                    child: Transform.translate(
                      offset: Offset(0, still ? 0 : 10 * (1 - logo)),
                      child: Transform.scale(
                        scale: still ? 1 : .86 + .14 * logo,
                        child: const BrandLogo(width: 250),
                      ),
                    ),
                  ),
                ),
                // Logo sekunder menyambung dari splash sistem, lalu memudar.
                if (secondary < 1)
                  _centered(
                    size: size,
                    centerY: size.height / 2,
                    extent: 160,
                    child: Opacity(
                      opacity: 1 - secondary,
                      child: Transform.scale(
                        scale: still ? 1 : 1 - .08 * secondary,
                        child: Image.asset(
                          BrandAssets.secondary,
                          width: 160,
                          height: 160,
                          excludeFromSemantics: true,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: taglineBottom,
                  child: Opacity(
                    opacity: tagline,
                    child: Transform.translate(
                      offset: Offset(0, still ? 0 : 6 * (1 - tagline)),
                      // Teks besar: mengecil agar tetap satu baris utuh.
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'BACA · BELAJAR · HAFAL',
                              maxLines: 1,
                              softWrap: false,
                              style: SacredText.splashTagline.copyWith(
                                color: tokens.goldText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Kotak [extent] × [height] berpusat di (tengah layar, [centerY]).
  Widget _centered({
    required Size size,
    required double centerY,
    required double extent,
    double? height,
    required Widget child,
  }) {
    final h = height ?? extent;
    return Positioned(
      left: (size.width - extent) / 2,
      top: centerY - h / 2,
      width: extent,
      height: h,
      child: child,
    );
  }
}
