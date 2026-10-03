import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/app/glass/glass_tier.dart';

/// Penilai frame murni (LIQUID_GLASS.md §7): jendela 120 frame, lebih dari
/// 8% frame melewati anggaran di dua jendela berturut-turut → turun satu
/// tingkat (full → lite → solid). Dipisah supaya bisa dites tanpa mesin.
class GlassFrameJudge {
  GlassFrameJudge({
    required this.budget,
    this.window = 120,
    this.limit = .08,
    this.badWindowsToLower = 2,
  });

  /// 1000/refreshRate ms.
  final Duration budget;
  final int window;
  final double limit;
  final int badWindowsToLower;

  int _frames = 0;
  int _late = 0;
  int _badWindows = 0;

  /// Masukkan durasi frame; mengembalikan tingkat baru bila harus turun.
  GlassTier? add(Iterable<Duration> frames, GlassTier current) {
    GlassTier? lowered;
    for (final frame in frames) {
      _frames++;
      if (frame > budget) _late++;
      if (_frames < window) continue;
      final bad = _late / _frames > limit;
      _frames = 0;
      _late = 0;
      _badWindows = bad ? _badWindows + 1 : 0;
      if (_badWindows < badWindowsToLower) continue;
      _badWindows = 0;
      final tier = lowered ?? current;
      if (tier == GlassTier.solid) continue;
      lowered = GlassTier.values[tier.index + 1];
    }
    return lowered;
  }
}

/// Jumlah kaca yang sedang terpasang; pengawas hanya bekerja bila > 0.
abstract final class GlassPresence {
  static final visible = ValueNotifier<int>(0);
}

/// Dipasang oleh `LiquidGlass`: menghitung kaca yang sedang ada di layar.
class GlassPresenceMarker extends StatefulWidget {
  const GlassPresenceMarker({super.key, required this.child});

  final Widget child;

  @override
  State<GlassPresenceMarker> createState() => _GlassPresenceMarkerState();
}

class _GlassPresenceMarkerState extends State<GlassPresenceMarker> {
  @override
  void initState() {
    super.initState();
    GlassPresence.visible.value++;
  }

  @override
  void dispose() {
    GlassPresence.visible.value--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Pengawas frame: aktif hanya saat "Efek kaca: Otomatis", ada kaca
/// terpasang, dan tingkat belum padat. Memakai
/// `SchedulerBinding.addTimingsCallback` (tanpa setState per frame, tanpa
/// log di rilis). Tingkat hanya turun di sesi yang sama dan disimpan oleh
/// [GlassController].
class GlassGovernor extends StatefulWidget {
  const GlassGovernor({
    super.key,
    required this.controller,
    required this.child,
  });

  final GlassController controller;
  final Widget child;

  @override
  State<GlassGovernor> createState() => _GlassGovernorState();
}

class _GlassGovernorState extends State<GlassGovernor> {
  GlassFrameJudge? _judge;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    GlassPresence.visible.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rate = View.maybeOf(context)?.display.refreshRate ?? 60;
    final budget = Duration(
      microseconds: (1000000 / (rate > 0 ? rate : 60)).round(),
    );
    if (_judge?.budget != budget) _judge = GlassFrameJudge(budget: budget);
    _update();
  }

  @override
  void didUpdateWidget(GlassGovernor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_update);
      widget.controller.addListener(_update);
      _update();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    GlassPresence.visible.removeListener(_update);
    _stop();
    super.dispose();
  }

  bool get _shouldListen =>
      widget.controller.preference == GlassPreference.auto &&
      widget.controller.autoTier != GlassTier.solid &&
      GlassPresence.visible.value > 0;

  void _update() {
    if (_shouldListen) {
      if (_listening) return;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _listening = true;
    } else {
      _stop();
    }
  }

  void _stop() {
    if (!_listening) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _listening = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    final judge = _judge;
    if (judge == null) return;
    final lowered = judge.add([
      for (final timing in timings) timing.totalSpan,
    ], widget.controller.autoTier);
    if (lowered == null) return;
    if (kDebugMode) debugPrint('Efek kaca diturunkan ke ${lowered.name}');
    widget.controller.lowerAutoTier(lowered);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
