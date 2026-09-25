import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_shell.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/onboarding/presentation/onboarding_screen.dart';
import 'package:quran_app_2025/features/onboarding/presentation/splash_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

enum _Stage { splash, onboarding, app }

/// Layar pertama aplikasi: splash animasi, lalu Onboarding (pengguna baru)
/// atau langsung Beranda. Perpindahannya fade-through 320 ms
/// (docs/design/v3/DESIGN.md §4b); mode kurangi gerak hanya fade 200 ms.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key, required this.ready});

  /// Inisialisasi layanan yang ditunggu splash (maksimal 2,5 detik).
  final Future<void> ready;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  _Stage _stage = _Stage.splash;
  int _tab = 0;

  void _afterSplash() {
    if (!mounted) return;
    setState(
      () => _stage = SharedPreferencesService.getOnboardingDone()
          ? _Stage.app
          : _Stage.onboarding,
    );
  }

  void _afterOnboarding(StartPoint point) {
    if (!mounted) return;
    setState(() {
      _tab = point.tabIndex;
      _stage = _Stage.app;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 200 : 320),
      transitionBuilder: (child, animation) =>
          _fadeThrough(child, animation, reduced: reduced),
      child: switch (_stage) {
        _Stage.splash => SplashScreen(
          key: const ValueKey(_Stage.splash),
          ready: widget.ready,
          onFinished: _afterSplash,
        ),
        _Stage.onboarding => OnboardingScreen(
          key: const ValueKey(_Stage.onboarding),
          onDone: _afterOnboarding,
        ),
        _Stage.app => AppShell(
          key: const ValueKey(_Stage.app),
          initialIndex: _tab,
        ),
      },
    );
  }

  /// Fade-through: layar lama memudar di 30% pertama, layar baru muncul di
  /// 70% sisanya sambil sedikit membesar (0.92 → 1).
  static Widget _fadeThrough(
    Widget child,
    Animation<double> animation, {
    required bool reduced,
  }) {
    if (reduced) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        if (animation.status == AnimationStatus.reverse) {
          // Layar keluar: nilai turun 1 → 0; hilang saat nilai < 0.7.
          final out = ((value - .7) / .3).clamp(0.0, 1.0);
          return Opacity(opacity: out, child: child);
        }
        final shown = const Interval(
          .3,
          1,
          curve: Curves.easeOut,
        ).transform(value);
        return Opacity(
          opacity: shown,
          child: Transform.scale(scale: .92 + .08 * shown, child: child),
        );
      },
    );
  }
}
