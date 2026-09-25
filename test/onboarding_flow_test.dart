import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/app_entry.dart';
import 'package:quran_app_2025/app/app_shell.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/onboarding/presentation/onboarding_screen.dart';
import 'package:quran_app_2025/features/onboarding/presentation/splash_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perilaku onboarding & splash v3 (docs/design/v3/screens/16-splash.md,
/// 17-onboarding.md, DESIGN v3 §4b dan §5).
void main() {
  Future<void> seed([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    await SharedPreferencesService.init();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) async {
    final controller = AppController();
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        // AppScope seperti di main.dart: tab Saya membutuhkannya.
        builder: (context, app) => AppScope(
          controller: controller,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: app!,
          ),
        ),
        home: child,
      ),
    );
    await tester.pump();
  }

  /// Panggilan haptik ke platform, dicatat per jenis.
  List<String> recordHaptics(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  group('onboarding', () {
    testWidgets('Lewati melompat ke halaman 4, bukan keluar', (tester) async {
      await seed();
      StartPoint? done;
      await pump(tester, OnboardingScreen(onDone: (point) => done = point));
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai dari mana?'), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);
      expect(done, isNull, reason: 'titik mulai belum dipilih');
      expect(SharedPreferencesService.getOnboardingDone(), isFalse);
    });

    testWidgets('pilih opsi lalu Mulai menyimpan preferensi', (tester) async {
      await seed();
      final haptics = recordHaptics(tester);
      StartPoint? done;
      await pump(tester, OnboardingScreen(onDone: (point) => done = point));
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Belum bisa membaca huruf Arab'));
      await tester.pumpAndSettle();
      expect(haptics, contains('HapticFeedbackType.lightImpact'));

      await tester.tap(find.text('Mulai'));
      await tester.pumpAndSettle();
      expect(done, StartPoint.nol);
      expect(SharedPreferencesService.getOnboardingDone(), isTrue);
      expect(SharedPreferencesService.getStartPoint(), 'nol');
      expect(StartPoint.nol.tabIndex, 2, reason: 'buka tab Belajar');
      expect(StartPoint.hafalan.tabIndex, 3, reason: 'buka tab Hafalan');
    });

    testWidgets('pilihan awal adalah nomor 2 (tajwid)', (tester) async {
      await seed();
      StartPoint? done;
      await pump(tester, OnboardingScreen(onDone: (point) => done = point));
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mulai'));
      await tester.pumpAndSettle();
      expect(done, StartPoint.tajwid);
      expect(SharedPreferencesService.getStartPoint(), 'tajwid');
    });

    testWidgets('tombol kembali mundur satu halaman; di halaman 1 keluar', (
      tester,
    ) async {
      await seed();
      final controller = PageController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        OnboardingScreen(controller: controller, onDone: (_) {}),
      );
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(controller.page, 2);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(await navigator.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(controller.page, 1, reason: 'mundur, bukan keluar');
      expect(await navigator.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      // Halaman 1: tidak ditahan lagi; kembali diteruskan ke sistem, yang
      // menutup aplikasi.
      expect(await navigator.maybePop(), isFalse);
      await tester.pumpAndSettle();
      expect(controller.page, 0);
    });

    testWidgets('geseran >20% pindah halaman dan memberi haptik', (
      tester,
    ) async {
      await seed();
      final haptics = recordHaptics(tester);
      final controller = PageController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        OnboardingScreen(controller: controller, onDone: (_) {}),
      );
      // 25% lebar, pelan: tetap pindah.
      await tester.timedDrag(
        find.byType(PageView),
        const Offset(-98, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));

      // 12% pelan: kembali ke halaman yang sama.
      await tester.timedDrag(
        find.byType(PageView),
        const Offset(-47, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.page, 1);
    });

    test('fisika: ambang 20% lebar atau kibasan 450 dp/s', () {
      final origin = SwipeOrigin()..page = 1;
      final physics = OnboardingPagePhysics(origin: origin);
      ScrollMetrics at(double page) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 390 * 3,
        pixels: page * 390,
        viewportDimension: 390,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 3,
      );
      expect(physics.targetPixels(at(1.21), 0), 2 * 390);
      expect(physics.targetPixels(at(1.19), 0), 1 * 390);
      expect(physics.targetPixels(at(0.79), 0), 0);
      expect(physics.targetPixels(at(0.81), 0), 1 * 390);
      // Kibasan cepat walau geseran pendek (> 16 dp).
      expect(physics.targetPixels(at(1.05), 500), 2 * 390);
      expect(physics.targetPixels(at(0.95), -500), 0);
      expect(physics.targetPixels(at(1.05), 400), 1 * 390);
      // Tidak melewati halaman pertama/terakhir.
      origin.page = 3;
      expect(physics.targetPixels(at(3), 900), 3 * 390);
    });

    testWidgets('kurangi gerak mematikan parallax', (tester) async {
      Future<double> titleShift({required bool reduce}) async {
        await seed();
        final controller = PageController();
        await pump(
          tester,
          OnboardingScreen(controller: controller, onDone: (_) {}),
          reduceMotion: reduce,
        );
        final title = find.textContaining('Selamat datang di');
        final before = tester.getTopLeft(title).dx;
        final gesture = await tester.startGesture(const Offset(200, 400));
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
        await gesture.moveBy(Offset(-(.5 - controller.page!) * 390, 0));
        await tester.pump();
        final shift = tester.getTopLeft(title).dx - before;
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        return shift;
      }

      // Dengan parallax judul ikut bergeser 1.1 × x; tanpa parallax diam.
      expect(await titleShift(reduce: false), lessThan(-150));
      expect(await titleShift(reduce: true), closeTo(0, .5));
    });
  });

  group('splash', () {
    testWidgets('selesai setelah minimal 1400 ms bila sudah siap', (
      tester,
    ) async {
      await seed();
      var finished = false;
      await pump(
        tester,
        SplashScreen(ready: Future.value(), onFinished: () => finished = true),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(finished, isTrue);
    });

    testWidgets('tidak pernah menahan lebih dari 2500 ms', (tester) async {
      await seed();
      var finished = false;
      await pump(
        tester,
        SplashScreen(
          ready: Completer<void>().future,
          onFinished: () => finished = true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 2400));
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(finished, isTrue);
    });

    /// Rotasi bintang (radian) pada saat [at] sejak animasi mulai.
    Future<double> starAngle(
      WidgetTester tester, {
      required bool reduce,
    }) async {
      await seed();
      await pump(
        tester,
        SplashScreen(ready: Future.value(), onFinished: () {}),
        reduceMotion: reduce,
      );
      // Animasi dimulai paling lambat 300 ms, lalu diamati di tengahnya.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      final rotate = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == 'EightPointStar',
              ),
              matching: find.byType(Transform),
            )
            .last,
      );
      final matrix = rotate.transform;
      final angle = matrix.entry(1, 0);
      await tester.pump(const Duration(seconds: 3));
      return angle;
    }

    testWidgets('dengan animasi: bintang berputar', (tester) async {
      expect((await starAngle(tester, reduce: false)).abs(), greaterThan(.01));
    });

    testWidgets('kurangi gerak: tanpa rotasi dan skala, hanya fade', (
      tester,
    ) async {
      expect(await starAngle(tester, reduce: true), 0);
      // Semua Transform di splash berupa identitas (tanpa skala/geser).
      await seed();
      await pump(
        tester,
        SplashScreen(ready: Future.value(), onFinished: () {}),
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      // Transform yang membungkus elemen splash (bintang, logo, tagline)
      // semuanya identitas: tanpa rotasi, skala, atau geser.
      for (final element in [
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'EightPointStar',
        ),
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'BrandLogo',
        ),
        find.text('BACA · BELAJAR · HAFAL'),
      ]) {
        final transforms = tester.widgetList<Transform>(
          find.ancestor(
            of: element,
            matching: find.descendant(
              of: find.byType(SplashScreen),
              matching: find.byType(Transform),
            ),
          ),
        );
        expect(transforms, isNotEmpty);
        for (final transform in transforms) {
          expect(transform.transform.isIdentity(), isTrue);
        }
      }
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('AppEntry', () {
    testWidgets('pengguna baru: splash lalu onboarding', (tester) async {
      await seed();
      await pump(tester, AppEntry(ready: Future.value()));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('sudah onboarding: splash lalu Beranda', (tester) async {
      await seed({'onboarding.selesai.v1': true});
      await pump(tester, AppEntry(ready: Future.value()));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.widget<AppShell>(find.byType(AppShell)).initialIndex, 0);
      // Biarkan pemuatan layar di tab selesai sebelum tes berakhir.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
