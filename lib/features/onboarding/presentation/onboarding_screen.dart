import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/onboarding/presentation/brand_art.dart';
import 'package:quran_app_2025/features/onboarding/presentation/splash_screen.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Onboarding 4 halaman yang bisa digeser
/// (docs/design/v3/screens/17-onboarding.md, DESIGN v3 §5).
///
/// Ilustrasi, judul, dan subjudul bergerak dengan kecepatan berbeda
/// (parallax) mengikuti `controller.page`; rumusnya DESIGN v3 §5c.
/// [onDone] dipanggil setelah pilihan titik mulai dan
/// `onboarding.selesai.v1` tersimpan.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.controller});

  final ValueChanged<StartPoint> onDone;

  /// Hanya untuk tes: controller dengan halaman awal tertentu.
  @visibleForTesting
  final PageController? controller;

  static const pageCount = 4;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pages = widget.controller ?? PageController();
  final _origin = SwipeOrigin();
  StartPoint _pick = StartPoint.initial;
  late int _settled = _pages.initialPage;
  bool _finishing = false;

  late final Future<_Ayah?> _ayah = _loadAyah();
  late final Future<Curriculum?> _curriculum = CurriculumRepository.load()
      .then<Curriculum?>((value) => value)
      .catchError((Object _) => null);

  static const _last = OnboardingScreen.pageCount - 1;

  @override
  void dispose() {
    if (widget.controller == null) _pages.dispose();
    super.dispose();
  }

  /// Posisi halaman saat ini (pecahan saat digeser).
  double get _page {
    if (!_pages.hasClients) return _pages.initialPage.toDouble();
    final position = _pages.position;
    if (!position.hasContentDimensions || !position.hasPixels) {
      return _pages.initialPage.toDouble();
    }
    return _pages.page ?? _pages.initialPage.toDouble();
  }

  /// Halaman terdekat: menentukan label CTA dan Lewati.
  int get _near => _page.round().clamp(0, _last);

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  Future<void> _go(int page) => _pages.animateToPage(
    page.clamp(0, _last),
    duration: Duration(milliseconds: _reduced ? 200 : 560),
    curve: brandEase,
  );

  void _next() {
    if (_near < _last) {
      unawaited(_go(_near + 1));
    } else {
      unawaited(_finish());
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final pick = _pick;
    await SharedPreferencesService.setStartPoint(pick.id);
    await SharedPreferencesService.setOnboardingDone();
    if (mounted) widget.onDone(pick);
  }

  void _choose(StartPoint point) {
    if (point == _pick) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _pick = point);
  }

  bool _onScroll(ScrollNotification notification) {
    // Hanya geseran halaman; gulir teks di dalam halaman diabaikan.
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _origin.page = _page.roundToDouble();
    } else if (notification is ScrollEndNotification) {
      _origin.page = null;
      final settled = _near;
      if (settled != _settled) {
        unawaited(HapticFeedback.selectionClick());
        setState(() => _settled = settled);
      }
    }
    return false;
  }

  static Future<_Ayah?> _loadAyah() async {
    // QS 2:5 dari dataset yang dibundel, tidak diketik (DESIGN v3 §5b).
    try {
      final verses = await QuranTextRepository.instance.versesForSurah(2);
      final text = verses[4];
      String? translation;
      try {
        translation = (await TranslationRepository.instance.forSurah(2))[4];
      } on Object {
        translation = null;
      }
      // Warna tajwid dari sumber yang aktif; bila dimatikan atau gagal,
      // ayat tampil tanpa warna.
      TajweedVerse? tajweed;
      if (SharedPreferencesService.getReaderTajweed()) {
        try {
          final surah = await TajweedRepository.instance.forSurah(2);
          if (surah.length > 4 && surah[4].text == text) tajweed = surah[4];
        } on Object {
          tajweed = null;
        }
      }
      return _Ayah(text: text, translation: translation, tajweed: tajweed);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final frame = _Frame(MediaQuery.of(context));
    return PopScope(
      // Tombol kembali di halaman 2–4 mundur satu halaman; di halaman 1
      // menutup aplikasi (DESIGN v3 §5a).
      canPop: _settled == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_go(_near - 1));
      },
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: AnimatedBuilder(
          animation: _pages,
          builder: (context, _) {
            final page = _page;
            final near = _near;
            // Semua anak Positioned; expand supaya Stack selalu selebar
            // layar (tanpa anak non-positioned ia bisa menyusut ke 0×0).
            return Stack(
              fit: StackFit.expand,
              children: [
                // Pola emas hanya di bagian atas, tidak ikut bergeser.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: FadingPattern(
                    color: tokens.gold.withValues(
                      alpha: tokens.isDark ? .06 : .07,
                    ),
                    height: frame.patternHeight,
                  ),
                ),
                for (var k = 0; k < OnboardingScreen.pageCount; k++)
                  if (_distance(k, page) < 1)
                    _Glow(page: k, t: _distance(k, page)),
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: PageView.builder(
                      controller: _pages,
                      // Snap sendiri: ambang 20% lebar atau 450 dp/s.
                      pageSnapping: false,
                      physics: OnboardingPagePhysics(
                        origin: _origin,
                        parent: const BouncingScrollPhysics(),
                      ),
                      itemCount: OnboardingScreen.pageCount,
                      itemBuilder: (context, k) => _buildPage(k, page, frame),
                    ),
                  ),
                ),
                _skip(near, frame),
                Positioned(
                  left: 0,
                  right: 0,
                  top: frame.dotsTop - _Dots.hitPad,
                  child: _Dots(page: page, onTap: _go),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: frame.ctaBottom,
                  child: _Cta(
                    label: near == _last ? 'Mulai' : 'Lanjut',
                    onTap: _next,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// `t = min(1, |k − page|)`: 0 di halaman itu, 1 satu halaman jauhnya.
  static double _distance(int k, double page) =>
      (k - page).abs().clamp(0.0, 1.0);

  Widget _skip(int near, _Frame frame) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final hidden = near == _last;
    return Positioned(
      right: 12,
      top: frame.top + 3,
      child: IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            // Lewati melompat ke halaman 4, bukan keluar: titik mulai
            // tetap perlu dipilih (DESIGN v3 §5a).
            child: Semantics(
              button: true,
              label: 'Lewati ke langkah terakhir',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_go(_last)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Text(
                    'Lewati',
                    maxLines: 1,
                    softWrap: false,
                    style: SacredText.skipLabel.copyWith(
                      color: tokens.primaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Satu halaman di dalam PageView. `x = (k − page) × lebar`; lapisan
  /// bergeser relatif terhadap halaman (DESIGN v3 §5c).
  Widget _buildPage(int k, double page, _Frame frame) {
    final x = (k - page) * frame.width;
    final t = _distance(k, page);
    final reduced = _reduced;
    // Kurangi gerak: tanpa parallax dan skala; halaman diam di tempat dan
    // hanya berganti lewat fade silang.
    final dx = reduced ? 0.0 : x;
    final illustrationScale = reduced ? 1.0 : 1 - .10 * t;
    final content = k == _last
        ? _lastPage(frame, dx, t, illustrationScale)
        : _illustratedPage(k, frame, dx, t, illustrationScale);
    Widget result = Semantics(
      container: true,
      label: 'Halaman ${k + 1} dari ${OnboardingScreen.pageCount}',
      child: content,
    );
    if (reduced) {
      result = Transform.translate(
        offset: Offset(-x, 0),
        child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: result),
      );
    }
    return result;
  }

  Widget _illustratedPage(
    int k,
    _Frame frame,
    double x,
    double t,
    double scale,
  ) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (title, subtitle) = _texts[k];
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: frame.illustrationTop,
          height: frame.illustrationHeight,
          child: _layer(
            dx: -.45 * x,
            scale: scale,
            opacity: 1 - .9 * t,
            // Ilustrasi digambar di kotak acuan 390×400 lalu diperkecil
            // bila layar lebih sempit/pendek; teksnya tidak ikut membesar.
            child: MediaQuery.withNoTextScaling(
              child: FittedBox(
                child: SizedBox(
                  width: 390,
                  height: 400,
                  child: switch (k) {
                    0 => const _WelcomeArt(),
                    1 => _ReadArt(ayah: _ayah),
                    _ => _LearnArt(curriculum: _curriculum),
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: frame.textTop,
          bottom: frame.textBottom,
          child: _FadeEdge(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  _layer(
                    dx: .10 * x,
                    opacity: 1 - 1.7 * t,
                    child: Semantics(
                      header: true,
                      child: Text.rich(
                        title,
                        textAlign: TextAlign.center,
                        style: SacredText.onboardingTitle.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _layer(
                    dx: .22 * x,
                    opacity: 1 - 2 * t,
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: SacredText.body.copyWith(color: tokens.sec),
                    ),
                  ),
                  // Ruang di bawah teks agar baris terakhir tidak ikut pudar.
                  const SizedBox(height: _FadeEdge.extent),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lastPage(_Frame frame, double x, double t, double scale) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: EdgeInsets.only(top: frame.headerTop, bottom: frame.textBottom),
      child: _FadeEdge(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _layer(
                dx: .10 * x,
                opacity: 1 - 1.7 * t,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LANGKAH TERAKHIR',
                        style: SacredText.eyebrow.copyWith(
                          color: tokens.goldText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          'Mulai dari mana?',
                          style: SacredText.onboardingTitleLarge.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Supaya materi pertama pas dengan kemampuanmu '
                        'sekarang.',
                        style: SacredText.body.copyWith(color: tokens.sec),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 52),
              _layer(
                dx: -.45 * x,
                scale: scale,
                opacity: 1 - .9 * t,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final point in StartPoint.values) ...[
                        if (point != StartPoint.values.first)
                          const SizedBox(height: 10),
                        _StartOption(
                          point: point,
                          selected: point == _pick,
                          onTap: () => _choose(point),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          8,
                          16,
                          8,
                          _FadeEdge.extent,
                        ),
                        // Panah digambar sebagai ikon: font yang dibundel tidak
                        // punya glyph "→".
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Bisa diubah kapan saja di Saya ',
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: LineIcon(
                                  SacredIcons.arrowRight,
                                  color: tokens.sec,
                                  size: 14,
                                ),
                              ),
                              const TextSpan(text: ' Belajar.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          semanticsLabel:
                              'Bisa diubah kapan saja di Saya, bagian Belajar.',
                          style: SacredText.onboardingNote.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lapisan parallax: geser X, skala, dan opasitas yang dijepit 0..1.
  static Widget _layer({
    required double dx,
    required double opacity,
    double scale = 1,
    required Widget child,
  }) {
    Widget result = child;
    if (scale != 1) result = Transform.scale(scale: scale, child: result);
    if (dx != 0) {
      result = Transform.translate(offset: Offset(dx, 0), child: result);
    }
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: result);
  }

  static final _texts = <(TextSpan, String)>[
    (
      const TextSpan(
        children: [
          TextSpan(text: 'Selamat datang di '),
          TextSpan(
            text: 'MyQuran',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      'Membaca, belajar, dan menghafal Al-Qur\'an dalam satu aplikasi yang '
          'tenang. Tetap bisa dibuka tanpa internet.',
    ),
    (
      const TextSpan(text: 'Baca seperti mushaf aslinya'),
      'Pilih 1 halaman, 2 halaman, atau kartu per ayat dengan terjemahan. '
          'Warna tajwid menempel langsung di hurufnya.',
    ),
    (
      const TextSpan(text: 'Belajar dari nol, lalu menghafal'),
      'Jalur bertahap dari mengenal huruf sampai tajwid, lalu hafalan dengan '
          'ziyadah dan murajaah yang terjadwal.',
    ),
  ];
}

/// Asal geseran yang sedang berlangsung, dibagi antara layar dan fisika.
class SwipeOrigin {
  /// Halaman (bulat) saat jari mulai menggeser, atau null.
  double? page;
}

/// Fisika halaman onboarding: pindah halaman bila geseran lebih dari 20%
/// lebar layar, atau kecepatan lebih dari 450 dp/s (DESIGN v3 §5c). Pantulan
/// di tepi mengikuti [parent] (BouncingScrollPhysics).
class OnboardingPagePhysics extends ScrollPhysics {
  const OnboardingPagePhysics({required this.origin, super.parent});

  final SwipeOrigin origin;

  static const threshold = .2;
  static const flingVelocity = 450.0;

  /// Geseran minimal agar kibasan cepat dihitung (seperti prototipe).
  static const flingMinDistance = 16.0;

  @override
  OnboardingPagePhysics applyTo(ScrollPhysics? ancestor) =>
      OnboardingPagePhysics(origin: origin, parent: buildParent(ancestor));

  /// Posisi tujuan (piksel) saat jari dilepas.
  @visibleForTesting
  double targetPixels(ScrollMetrics position, double velocity) {
    final width = position.viewportDimension;
    if (width <= 0) return position.pixels;
    final page = position.pixels / width;
    final from = origin.page ?? page.roundToDouble();
    final dragged = (page - from) * width;
    var target = from;
    if (dragged > width * threshold ||
        (velocity > flingVelocity && dragged > flingMinDistance)) {
      target = from + 1;
    } else if (dragged < -width * threshold ||
        (velocity < -flingVelocity && dragged < -flingMinDistance)) {
      target = from - 1;
    }
    // Geseran lebih dari satu halaman: berhenti di halaman terdekat.
    if ((page - target).abs() > 1) target = page.roundToDouble();
    final first = position.minScrollExtent / width;
    final last = position.maxScrollExtent / width;
    return target.clamp(first, last) * width;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = targetPixels(position, velocity);
    if ((target - position.pixels).abs() <= tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Ukuran tata letak dari layar acuan 390×844 (bilah status 47): Lewati di
/// y=50, ilustrasi 96–496, teks mulai 520, titik 716, CTA 34 dari bawah.
/// Layar lebih pendek memperkecil ilustrasi, bukan memotong teks.
class _Frame {
  factory _Frame(MediaQueryData media) {
    final height = media.size.height;
    final top = media.padding.top;
    final ctaBottom = math.max(34.0, media.padding.bottom + 10);
    final dotsTop = height - ctaBottom - _Cta.height - 38;
    final illustrationTop = top + 49;
    final region = dotsTop - illustrationTop;
    final large = media.textScaler.scale(1) > 1.3;
    final illustrationHeight = math.max(
      0.0,
      large
          ? math.min(400.0, math.min(height * .45, region * .45))
          : math.min(400.0, region * .6452),
    );
    return _Frame._(
      width: media.size.width,
      height: height,
      top: top,
      ctaBottom: ctaBottom,
      dotsTop: dotsTop,
      illustrationTop: illustrationTop,
      illustrationHeight: illustrationHeight,
      textTop: illustrationTop + illustrationHeight + 24,
      textBottom: height - (dotsTop - 12),
      headerTop: top + 71,
      patternHeight: 520 * height / 844,
    );
  }

  const _Frame._({
    required this.width,
    required this.height,
    required this.top,
    required this.ctaBottom,
    required this.dotsTop,
    required this.illustrationTop,
    required this.illustrationHeight,
    required this.textTop,
    required this.textBottom,
    required this.headerTop,
    required this.patternHeight,
  });

  final double width;
  final double height;
  final double top;
  final double ctaBottom;
  final double dotsTop;
  final double illustrationTop;
  final double illustrationHeight;
  final double textTop;

  /// Jarak dari bawah layar ke batas bawah area teks.
  final double textBottom;
  final double headerTop;
  final double patternHeight;
}

/// Tepi bawah area teks yang memudar 24 dp: tanda bahwa teks bisa digulir
/// (teks besar), tanpa memotong baris secara kasar.
class _FadeEdge extends StatelessWidget {
  const _FadeEdge({required this.child});

  final Widget child;

  static const extent = 24.0;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
      stops: [0, math.max(0, 1 - extent / math.max(1, bounds.height)), 1],
    ).createShader(bounds),
    child: child,
  );
}

/// Glow latar halaman [page], memudar `1 − t`; tidak ikut bergeser.
class _Glow extends StatelessWidget {
  const _Glow({required this.page, required this.t});

  final int page;
  final double t;

  /// Pusat glow tiap halaman (HTML acuan).
  static const _centers = [
    Offset(.5, .26),
    Offset(.30, .22),
    Offset(.72, .24),
    Offset(.5, .12),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final opacity = (1 - t).clamp(0.0, 1.0);
    final colors = tokens.isDark ? SacredGlow.pagesDark : SacredGlow.pagesLight;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: EllipseGlow(
            inner: colors[page],
            center: _centers[page],
            radii: const Offset(1.2, .7),
            stop: .62,
          ),
        ),
      ),
    );
  }
}

/// Titik halaman: lebar `7 + 15·(1−t)`; warna bergeser dari titik diam ke
/// titik aktif. Setiap titik adalah tombol berlabel.
class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.onTap});

  final double page;
  final ValueChanged<int> onTap;

  /// Ruang ketuk di atas dan bawah titik 7 dp.
  static const hitPad = 18.5;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final current = page.round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 0; k < OnboardingScreen.pageCount; k++)
          Semantics(
            button: true,
            selected: k == current,
            label: 'Halaman ${k + 1} dari ${OnboardingScreen.pageCount}',
            excludeSemantics: true,
            onTap: () => onTap(k),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(k),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 3.5,
                  vertical: hitPad,
                ),
                child: Container(
                  width: 7 + 15 * _closeness(k),
                  height: 7,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      tokens.surf2,
                      tokens.primaryText,
                      _closeness(k),
                    ),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// `1 − t` untuk titik ke-[k].
  double _closeness(int k) => 1 - (k - page).abs().clamp(0.0, 1.0);
}

/// CTA pill 56: "Lanjut", di halaman terakhir "Mulai". Labelnya berganti
/// dengan AnimatedSwitcher 200 ms.
class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: tokens.cta,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: height),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                key: ValueKey(label),
                textAlign: TextAlign.center,
                style: SacredText.onboardingCta.copyWith(color: tokens.ctaInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan titik mulai (radio).
class _StartOption extends StatelessWidget {
  const _StartOption({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final StartPoint point;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    StartPoint.nol: SacredIcons.cap,
    StartPoint.tajwid: SacredIcons.book,
    StartPoint.hafalan: SacredIcons.layers,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${point.title}. ${point.subtitle}',
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: brandEase,
        // Cincin pilihan berupa garis di luar kartu, bukan bayangan: di
        // tema gelap latar primarySoft tembus pandang, jadi bayangan pekat
        // akan terlihat memenuhi kartu.
        decoration: BoxDecoration(
          color: selected ? tokens.primarySoft : tokens.surf,
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? tokens.primaryText
                : tokens.primaryText.withValues(alpha: 0),
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: selected ? null : tokens.cardShadows,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.cta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LineIcon(
                      _icons[point]!,
                      color: tokens.ctaInk,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.title,
                          style: SacredText.optionTitle.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          point.subtitle,
                          style: SacredText.optionSubtitle.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.primaryText, width: 2),
                    ),
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tokens.primaryText,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Halaman 1: logo utama 236 di atas halo dan bintang 316.
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Stack(
      alignment: Alignment.center,
      children: [
        RoundGlow(
          size: 330,
          color: tokens.isDark ? SacredGlow.haloDark : SacredGlow.haloLight,
          stop: .7,
        ),
        Opacity(
          opacity: tokens.isDark ? .30 : .38,
          child: EightPointStar(size: 316, color: tokens.gold, strokeWidth: .9),
        ),
        const BrandLogo(width: 236, semanticLabel: 'Logo MyQuran'),
      ],
    );
  }
}

/// Ayat contoh halaman 2.
class _Ayah {
  const _Ayah({required this.text, this.translation, this.tajweed});

  final String text;
  final String? translation;
  final TajweedVerse? tajweed;
}

/// Halaman 2: kartu ayat QS 2:5 di antara dua kartu halaman abstrak dan
/// chip mode baca.
class _ReadArt extends StatelessWidget {
  const _ReadArt({required this.ayah});

  final Future<_Ayah?> ayah;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final dark = tokens.isDark;
    final paper = dark ? SacredGlow.paperDark : SacredGlow.paperLight;
    final line = dark ? SacredGlow.paperLineDark : SacredGlow.paperLineLight;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 18,
          top: 84,
          width: 132,
          height: 196,
          child: Transform.rotate(
            angle: -9 * math.pi / 180,
            child: _PaperCard(
              color: paper,
              line: line,
              header: tokens.gold,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              columns: 1,
              lineWidth: 104,
              gap: 9,
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 150,
          width: 150,
          height: 108,
          child: Transform.rotate(
            angle: 8 * math.pi / 180,
            child: _PaperCard(
              color: paper,
              line: line,
              divider: tokens.sep,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              columns: 2,
              lineWidth: 58,
              gap: 7,
            ),
          ),
        ),
        Positioned(
          left: 79,
          top: 24,
          width: 232,
          child: _VerseCard(ayah: ayah),
        ),
        // Chip tetap satu baris utuh; bila font lebih lebar, mengecil.
        const Positioned(
          left: 12,
          right: 12,
          top: 352,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeChip(icon: SacredIcons.pageSingle, label: '1 halaman'),
                SizedBox(width: 6),
                _ModeChip(icon: SacredIcons.pageDouble, label: '2 halaman'),
                SizedBox(width: 6),
                _ModeChip(
                  icon: SacredIcons.cards,
                  label: 'Kartu',
                  active: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.ayah});

  final Future<_Ayah?> ayah;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.floatShadows,
      ),
      child: FutureBuilder<_Ayah?>(
        future: ayah,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RosetteBadge(
                    label: '5',
                    size: 28,
                    outlined: true,
                    textColor: tokens.ink,
                    textStyle: SacredText.rosetteNumber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Al-Baqarah · 5',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.illustrationLabel.copyWith(
                        color: tokens.sec,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data == null)
                // Menunggu dataset: ruang dua baris ayat, tanpa teks tebakan.
                const SizedBox(height: 88)
              else
                Text.rich(
                  TextSpan(
                    children: data.tajweed == null
                        ? [TextSpan(text: data.text)]
                        : tajweedSpans(
                            data.tajweed!,
                            palette: TajweedPalette.draftPreview,
                            brightness: tokens.isDark
                                ? Brightness.dark
                                : Brightness.light,
                            base: tokens.ink,
                          ),
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: 21,
                    height: 44 / 21,
                    color: tokens.ink,
                  ),
                ),
              if (data?.translation case final translation?) ...[
                const SizedBox(height: 8),
                Text(
                  translation,
                  style: SacredText.illustrationBody.copyWith(
                    color: tokens.sec,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Kartu halaman abstrak: garis-garis, bukan teks Arab palsu.
class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.color,
    required this.line,
    required this.radius,
    required this.padding,
    required this.columns,
    required this.lineWidth,
    required this.gap,
    this.header,
    this.divider,
  });

  final Color color;
  final Color line;
  final double radius;
  final EdgeInsets padding;
  final int columns;
  final double lineWidth;
  final double gap;
  final Color? header;
  final Color? divider;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: tokens.floatShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _PaperLines(
            line: line,
            padding: padding,
            columns: columns,
            lineWidth: lineWidth,
            gap: gap,
            header: header,
            divider: divider,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PaperLines extends CustomPainter {
  const _PaperLines({
    required this.line,
    required this.padding,
    required this.columns,
    required this.lineWidth,
    required this.gap,
    this.header,
    this.divider,
  });

  final Color line;
  final EdgeInsets padding;
  final int columns;
  final double lineWidth;
  final double gap;
  final Color? header;
  final Color? divider;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = padding.deflateRect(Offset.zero & size);
    final fill = Paint()..color = line;
    // Kolom dipisah garis 1 px dengan jarak 8 di kiri dan kanannya.
    const split = 8.0;
    final columnWidth =
        (inner.width - (columns - 1) * (split * 2 + 1)) / columns;
    for (var c = 0; c < columns; c++) {
      final left = inner.left + c * (columnWidth + split * 2 + 1);
      final right = left + columnWidth;
      var y = inner.top;
      final headerColor = header;
      if (headerColor != null && c == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + .5, y + .5, columnWidth - 1, 15),
            const Radius.circular(8),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = headerColor.withValues(alpha: headerColor.a * .8),
        );
        y += 16 + gap;
      }
      // Tiap baris keempat lebih pendek, rata kanan seperti tulisan Arab.
      var i = 0;
      while (y + 4 <= inner.bottom) {
        final short = i % 4 == 3;
        final width = math.min(lineWidth * (short ? .6 : 1), columnWidth);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(right - width, y, width, 4),
            const Radius.circular(2),
          ),
          fill,
        );
        y += 4 + gap;
        i++;
      }
      final dividerColor = divider;
      if (dividerColor != null && c < columns - 1) {
        canvas.drawRect(
          Rect.fromLTWH(right + split, inner.top, 1, inner.height),
          Paint()..color = dividerColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PaperLines old) =>
      old.line != line ||
      old.columns != columns ||
      old.header != header ||
      old.divider != divider;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final List<String> icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final color = active ? tokens.primaryText : tokens.sec;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? tokens.surf : tokens.fill,
        borderRadius: BorderRadius.circular(17),
        boxShadow: active ? tokens.cardShadows : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LineIcon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: SacredText.illustrationLabel.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Halaman 3: kartu jalur belajar (judul tahap dari curriculum.json) dan
/// kartu hafalan. Nilai hafalan adalah contoh tetap, jadi ilustrasi ini
/// diberi label "Ilustrasi" dan isinya disembunyikan dari pembaca layar.
class _LearnArt extends StatelessWidget {
  const _LearnArt({required this.curriculum});

  final Future<Curriculum?> curriculum;

  /// Tahap yang ditampilkan: tiga selesai lalu tahap 10 sebagai tahap aktif.
  static const _done = [1, 3, 4];
  static const _current = 10;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      label: 'Ilustrasi',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 24,
              top: 8,
              width: 270,
              child: FutureBuilder<Curriculum?>(
                future: curriculum,
                builder: (context, snapshot) {
                  String titleOf(int level) =>
                      snapshot.data?.lessons
                          .where((lesson) => lesson.level == level)
                          .firstOrNull
                          ?.title ??
                      '';
                  return _PathCard(
                    done: [for (final level in _done) (level, titleOf(level))],
                    current: (_current, titleOf(_current)),
                  );
                },
              ),
            ),
            Positioned(
              right: 18,
              top: 300,
              width: 184,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.surf,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: tokens.floatShadows,
                ),
                child: Row(
                  children: [
                    ProgressRing(
                      value: .6,
                      size: 58,
                      stroke: 7,
                      color: tokens.gold,
                      child: Text(
                        '60%',
                        style: SacredText.ringPercent.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HAFALAN',
                            maxLines: 1,
                            style: SacredText.eyebrow.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Seperti acuan (nowrap): teks boleh melewati
                          // bantalan kanan, tidak dipotong.
                          Text(
                            'Al-Mulk 1–10',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: SacredText.goalTitle.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Murajaah: 3 ayat',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: SacredText.pathNote.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.done, required this.current});

  final List<(int, String)> done;
  final (int, String) current;

  /// Hukum nun sukun & tanwin beserta warna tajwidnya; izhar tidak diwarnai.
  static const _rules = <(String, TajweedRule?)>[
    ('Izhar', null),
    ('Idgham', TajweedRule.idghamBighunnah),
    ('Iqlab', TajweedRule.iqlab),
    ('Ikhfa', TajweedRule.ikhfaHaqiqi),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final brightness = tokens.isDark ? Brightness.dark : Brightness.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.floatShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JALUR BELAJAR',
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          for (final (level, title) in done) ...[
            const SizedBox(height: 12),
            _PathRow(
              node: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: LineIcon(
                  SacredIcons.checkCircle,
                  color: tokens.primaryText,
                  size: 20,
                  strokeWidth: 2.2,
                ),
              ),
              title: title,
              note: 'Tahap $level',
              muted: true,
              connector: true,
            ),
          ],
          const SizedBox(height: 12),
          _PathRow(
            node: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.cta,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: tokens.primarySoft, spreadRadius: 5),
                ],
              ),
              child: Text(
                '${current.$1}',
                style: SacredText.stepNumber.copyWith(color: tokens.ctaInk),
              ),
            ),
            title: current.$2,
            note: 'Tahap ${current.$1} · 5 hukum',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, rule) in _rules)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.fill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rule != null) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: TajweedPalette.draftPreview.colorFor(
                                rule,
                                brightness,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: SacredText.ruleChip.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.node,
    required this.title,
    required this.note,
    this.muted = false,
    this.connector = false,
  });

  final Widget node;
  final String title;
  final String note;
  final bool muted;

  /// Garis penghubung ke baris berikutnya.
  final bool connector;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (connector)
          Positioned(
            left: 12.25,
            top: 30,
            bottom: -8,
            width: 1.5,
            child: ColoredBox(color: tokens.sep),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Row(
            children: [
              node,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.pathTitle.copyWith(
                        color: muted ? tokens.sec : tokens.ink,
                      ),
                    ),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.pathNote.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
