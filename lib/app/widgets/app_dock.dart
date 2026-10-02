import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/murottal/presentation/now_playing_row.dart';

/// Tab bar + "sedang diputar" dalam satu permukaan kaca
/// (docs/design/v6/screens/21-dock.md). Menggantikan `FloatingTabBar` dan
/// `AudioMiniPlayer`.
///
/// - Satu [LiquidGlass] radius 32, margin 12, jarak bawah max(24, inset
///   gestur). Baris [NowPlayingRow] muncul di atas tab dengan `AnimatedSize`
///   pegas (massa 1, kekakuan 380, redaman 30); tinggi 64 → 135.
/// - Lensa tab meluncur dengan pegas 420/32 dan meregang searah gerak
///   (LIQUID_GLASS.md §6); geser jari di dock memindahkan lensa.
/// - Tinggi yang harus disisakan halaman: [AppDock.reservedHeightOf].
class AppDock extends StatefulWidget {
  const AppDock({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    this.audio,
    this.onOpenPlayer,
    this.reserved,
  });

  final List<SacredTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Sumber "sedang diputar"; tanpa ini dock hanya berisi tab.
  final NowPlayingAudio? audio;

  /// Membuka layar Murottal (ketuk / geser atas baris sedang diputar).
  final VoidCallback? onOpenPlayer;

  /// Diisi dock dengan tinggi yang harus disisakan halaman; disediakan ke
  /// halaman lewat [AppDockScope].
  final ValueNotifier<double>? reserved;

  static const tabsHeight = 64.0;

  /// Baris sedang diputar + garis pemisah (21-dock.md: 62 + 9).
  static const nowPlayingHeight = NowPlayingRow.height + 9;

  /// Jarak dari isi terakhir ke dock.
  static const contentGap = 16.0;

  /// Ruang bawah bila tidak ada [AppDockScope] (mis. golden satu layar):
  /// dock diam 64 + jarak bawah 24 + 16, sama dengan tab bar lama.
  static const defaultReserved = tabsHeight + 24 + contentGap;

  /// Tinggi dock saat ini + jarak bawah + 16. Halaman yang memanggil ini
  /// ikut dibangun ulang saat dock memanjang/memendek.
  static double reservedHeightOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppDockScope>()
          ?.notifier
          ?.value ??
      defaultReserved;

  /// Rumus ruang bawah untuk keadaan dock tertentu.
  static double reservedFor({
    required bool expanded,
    required double bottomInset,
  }) =>
      tabsHeight +
      (expanded ? nowPlayingHeight : 0) +
      math.max(24, bottomInset) +
      contentGap;

  @override
  State<AppDock> createState() => _AppDockState();
}

/// Menyediakan tinggi ruang bawah dock untuk halaman-halaman tab.
class AppDockScope extends InheritedNotifier<ValueNotifier<double>> {
  const AppDockScope({
    super.key,
    required ValueNotifier<double> reserved,
    required super.child,
  }) : super(notifier: reserved);
}

class _AppDockState extends State<AppDock> {
  @override
  void initState() {
    super.initState();
    widget.audio?.addListener(_onAudio);
  }

  @override
  void didUpdateWidget(AppDock old) {
    super.didUpdateWidget(old);
    if (old.audio != widget.audio) {
      old.audio?.removeListener(_onAudio);
      widget.audio?.addListener(_onAudio);
    }
  }

  @override
  void dispose() {
    widget.audio?.removeListener(_onAudio);
    super.dispose();
  }

  bool get _expanded {
    final audio = widget.audio;
    return audio != null &&
        audio.queue != null &&
        NowPlayingAudio.ayahOf(audio.playingVerse) != null;
  }

  void _onAudio() {
    if (!mounted) return;
    setState(() {});
  }

  /// Tinggi ruang bawah diperbarui setelah frame, bukan di tengah build,
  /// karena halaman lain bergantung padanya.
  void _syncReserved(double bottomInset) {
    final reserved = widget.reserved;
    if (reserved == null) return;
    final value = AppDock.reservedFor(
      expanded: _expanded,
      bottomInset: bottomInset,
    );
    if (reserved.value == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) reserved.value = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final expanded = _expanded;
    _syncReserved(bottomInset);
    final audio = widget.audio;

    final playing = expanded && audio != null
        ? Column(
            key: const ValueKey('sedang-diputar'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
                child: NowPlayingRow(
                  audio: audio,
                  heroTag: NowPlayingRow.murottalHeroTag,
                  onOpen: widget.onOpenPlayer ?? () {},
                ),
              ),
              Container(height: 1, color: tokens.sep),
            ],
          )
        : const SizedBox(
            key: ValueKey('kosong'),
            width: double.infinity,
            height: 0,
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(24, bottomInset)),
      // Label tab kecil; penskalaannya dibatasi seperti tab bar iOS.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(32),
          interactive: true,
          sheenOffset: widget.tabs.length < 2
              ? 0
              : widget.currentIndex / (widget.tabs.length - 1) * 2 - 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: Duration(milliseconds: reduceMotion ? 150 : 360),
                curve: reduceMotion
                    ? Curves.linear
                    : const SpringCurve(
                        SpringDescription(mass: 1, stiffness: 380, damping: 30),
                        .36,
                      ),
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: reduceMotion
                        ? child
                        : SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 8 / 62),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                  ),
                  child: playing,
                ),
              ),
              SizedBox(
                height: AppDock.tabsHeight,
                child: _DockTabs(
                  tabs: widget.tabs,
                  currentIndex: widget.currentIndex,
                  onSelected: widget.onSelected,
                  reduceMotion: reduceMotion,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lima tab dengan satu lensa kaca yang meluncur di antaranya.
class _DockTabs extends StatefulWidget {
  const _DockTabs({
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    required this.reduceMotion,
  });

  final List<SacredTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool reduceMotion;

  @override
  State<_DockTabs> createState() => _DockTabsState();
}

class _DockTabsState extends State<_DockTabs> with TickerProviderStateMixin {
  /// Pegas lensa (LIQUID_GLASS.md §6): ±350 ms, lewatan ≤ 4%.
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 32,
  );

  /// Kecepatan (tab/detik) yang dianggap regangan penuh.
  static const _fullStretchVelocity = 10.0;

  /// Posisi lensa dalam satuan tab (0 = tab pertama).
  late final AnimationController _lens = AnimationController.unbounded(
    vsync: this,
    value: widget.currentIndex.toDouble(),
  );

  /// Crossfade 150 ms saat "Kurangi gerak" aktif.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1,
  );

  bool _pressed = false;
  int? _hover;
  double _tabWidth = 1;

  @override
  void didUpdateWidget(_DockTabs old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _moveTo(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _moveTo(double target, {double velocity = 0}) {
    if (widget.reduceMotion) {
      _lens.value = target;
      _fade.forward(from: 0);
      return;
    }
    _lens.animateWith(SpringSimulation(_spring, _lens.value, target, velocity));
  }

  void _select(int index) {
    if (index != widget.currentIndex) {
      HapticFeedback.selectionClick();
      widget.onSelected(index);
    } else {
      _moveTo(index.toDouble());
    }
  }

  double _positionAt(double dx) =>
      (dx / _tabWidth - .5).clamp(0.0, widget.tabs.length - 1.0);

  void _dragUpdate(DragUpdateDetails details) {
    _lens.stop();
    _lens.value = _positionAt(details.localPosition.dx);
    final nearest = _lens.value.round();
    if (nearest != (_hover ?? widget.currentIndex)) {
      HapticFeedback.selectionClick();
      setState(() => _hover = nearest);
    }
  }

  void _dragEnd(DragEndDetails details) {
    final target = _lens.value.round();
    final velocity = (details.primaryVelocity ?? 0) / _tabWidth;
    setState(() => _hover = null);
    if (target != widget.currentIndex) {
      widget.onSelected(target);
      // didUpdateWidget menggerakkan lensa; kecepatan jari ikut dibawa.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _moveTo(target.toDouble(), velocity: velocity),
      );
    } else {
      _moveTo(target.toDouble(), velocity: velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final active = _hover ?? widget.currentIndex;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, box) {
          _tabWidth = box.maxWidth / widget.tabs.length;
          final lens = RepaintBoundary(
            child: AnimatedScale(
              scale: _pressed ? .94 : 1,
              duration: const Duration(milliseconds: 90),
              child: FadeTransition(
                opacity: _fade,
                child: LiquidGlass(
                  size: GlassSize.small,
                  borderRadius: BorderRadius.circular(28),
                  // primarySoft gelap transparan: dikomposit dulu di atas surf
                  // (warna tab aktif lama), baru alfanya 92%. Tanpa ini,
                  // tingkat padat/kontras tinggi membuat lensa mint pekat dan
                  // label primaryText tidak terbaca.
                  tint: Color.alphaBlend(
                    tokens.primarySoft,
                    tokens.surf,
                  ).withValues(alpha: .92),
                  shadow: false,
                  child: SizedBox(width: _tabWidth, height: box.maxHeight),
                ),
              ),
            ),
          );
          return Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _dragUpdate,
              onHorizontalDragEnd: _dragEnd,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _lens,
                    builder: (context, child) {
                      final v = widget.reduceMotion
                          ? 0.0
                          : (_lens.velocity.abs() / _fullStretchVelocity).clamp(
                              0.0,
                              1.0,
                            );
                      return Positioned(
                        left: _lens.value * _tabWidth,
                        top: 0,
                        bottom: 0,
                        child: Transform.scale(
                          scaleX: 1 + .12 * v,
                          scaleY: 1 - .06 * v,
                          child: child,
                        ),
                      );
                    },
                    child: lens,
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        Expanded(
                          child: _DockTab(
                            tab: widget.tabs[i],
                            selected: i == active,
                            onTap: () => _select(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu tab: ikon 22 + label 11, tanpa ripple. Label tidak pernah dielipsis.
class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SacredTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final color = selected ? tokens.primaryText : tokens.ink;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LineIcon(
              tab.icon,
              color: color,
              size: 22,
              strokeWidth: selected
                  ? SacredIcons.strokeNavActive
                  : SacredIcons.strokeNav,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                softWrap: false,
                style: (selected ? SacredText.tabActive : SacredText.tabIdle)
                    .copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kurva dari [SpringSimulation] 0 → 1 untuk animasi berdurasi tetap
/// (mis. `AnimatedSize`). [seconds] = durasi animasinya.
class SpringCurve extends Curve {
  const SpringCurve(this.spring, this.seconds);

  final SpringDescription spring;
  final double seconds;

  @override
  double transformInternal(double t) =>
      SpringSimulation(spring, 0, 1, 0).x(t * seconds);
}
