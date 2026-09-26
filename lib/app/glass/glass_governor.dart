import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';

/// Pengawas frame (LIQUID_GLASS.md §7): bila HP tidak kuat, tingkat kaca
/// otomatis turun penuh → ringan → padat.
///
/// - Hanya mendengar saat preferensi "Otomatis", tingkatnya belum padat, dan
///   ada layar berkaca yang sedang tampil ([GlassGovernorScope]).
/// - Jendela 120 frame; anggaran 1000 / refresh rate ms. Lebih dari 8% frame
///   melewati anggaran di dua jendela berturut-turut → turun satu tingkat.
/// - Tidak pernah naik di sesi yang sama (lihat [GlassController.setAutoTier]).
/// - Callback hanya menghitung angka: tanpa setState per frame, tanpa log.
class GlassGovernor {
  GlassGovernor(this.controller, {this.window = 120, this.slowShare = .08}) {
    controller.addListener(_update);
  }

  final GlassController controller;

  /// Jumlah frame per jendela.
  final int window;

  /// Bagian frame lambat yang membuat satu jendela dianggap buruk.
  final double slowShare;

  Duration _budget = const Duration(microseconds: 16667);
  int _frames = 0;
  int _slow = 0;
  int _badWindows = 0;
  int _visible = 0;
  bool _listening = false;

  /// Sedang mendengar timing frame.
  bool get listening => _listening;

  /// Anggaran satu frame saat ini.
  Duration get budget => _budget;

  bool get _shouldListen =>
      _visible > 0 &&
      controller.preference == GlassPreference.auto &&
      controller.autoTier != GlassTier.solid;

  /// Dipanggil oleh layar berkaca yang mulai tampil.
  void show(double refreshRate) {
    _visible++;
    setRefreshRate(refreshRate);
    _update();
  }

  /// Dipanggil saat layar berkaca tertutup atau tidak lagi di depan.
  void hide() {
    if (_visible > 0) _visible--;
    _update();
  }

  void setRefreshRate(double refreshRate) {
    final hz = refreshRate.isFinite && refreshRate >= 30 ? refreshRate : 60.0;
    _budget = Duration(microseconds: (1e6 / hz).round());
  }

  void _update() {
    final should = _shouldListen;
    if (should == _listening) return;
    _listening = should;
    _reset();
    if (should) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
  }

  void _reset() {
    _frames = 0;
    _slow = 0;
    _badWindows = 0;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      record(timing.totalSpan);
    }
  }

  /// Mencatat satu frame. Dipisah dari callback supaya bisa diuji.
  @visibleForTesting
  void record(Duration totalSpan) {
    if (!_listening) return;
    _frames++;
    if (totalSpan > _budget) _slow++;
    if (_frames < window) return;
    final bad = _slow / _frames > slowShare;
    _badWindows = bad ? _badWindows + 1 : 0;
    _frames = 0;
    _slow = 0;
    if (_badWindows < 2) return;
    _badWindows = 0;
    final next = GlassTier.values[controller.autoTier.index + 1];
    // Tanpa await: menyimpan preferensi tidak perlu ditunggu di callback.
    controller.setAutoTier(next);
  }

  void dispose() {
    controller.removeListener(_update);
    if (_listening) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _listening = false;
  }
}

/// Menandai bahwa layar berkaca di bawahnya sedang tampil, supaya pengawas
/// frame hanya bekerja saat ada kaca. Dipasang di AppShell dan pembaca.
class GlassGovernorScope extends StatefulWidget {
  const GlassGovernorScope({super.key, required this.child});

  final Widget child;

  @override
  State<GlassGovernorScope> createState() => _GlassGovernorScopeState();
}

class _GlassGovernorScopeState extends State<GlassGovernorScope> {
  GlassGovernor? _governor;
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final governor = GlassScope.maybeOf(context)?.governor;
    // Rute yang tertutup rute lain (layar penuh atau sheet) tidak dihitung.
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (governor != _governor) {
      _setShown(false);
      _governor = governor;
    }
    governor?.setRefreshRate(View.of(context).display.refreshRate);
    _setShown(visible);
  }

  void _setShown(bool value) {
    final governor = _governor;
    if (governor == null || value == _shown) return;
    _shown = value;
    if (value) {
      governor.show(View.of(context).display.refreshRate);
    } else {
      governor.hide();
    }
  }

  @override
  void dispose() {
    if (_shown) _governor?.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
