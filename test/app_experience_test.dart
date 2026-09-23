import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menggulir daftar sampai [finder] terbangun; ListView membangun anaknya
/// secara lazy sehingga yang di luar layar belum ada di pohon widget.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
  }
}

Widget _host(Widget child) =>
    MaterialApp(theme: SacredTheme.light, home: Scaffold(body: child));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  group('palet warna', () {
    test('bawaan hijau dan tersimpan setelah dipilih', () async {
      expect(SharedPreferencesService.getPalette(), AppPalette.sacred);
      await SharedPreferencesService.setPalette(AppPalette.sepia);
      expect(SharedPreferencesService.getPalette(), AppPalette.sepia);
    });

    test('sepia dan kontras tinggi mengubah warna permukaan dan teks', () {
      final sacred = SacredTheme.themeFor(AppPalette.sacred, Brightness.light);
      final sepia = SacredTheme.themeFor(AppPalette.sepia, Brightness.light);
      final contrast = SacredTheme.themeFor(
        AppPalette.highContrast,
        Brightness.light,
      );

      expect(sepia.colorScheme.surface, isNot(sacred.colorScheme.surface));
      expect(sepia.scaffoldBackgroundColor, const Color(0xFFF4ECD8));
      expect(contrast.colorScheme.onSurface, const Color(0xFF000000));
      expect(contrast.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      // Bentuk komponen tidak ikut berubah, hanya warnanya.
      expect(sepia.cardTheme.elevation, sacred.cardTheme.elevation);
    });

    test('kontras teks pada palet kontras tinggi maksimal', () {
      for (final brightness in Brightness.values) {
        final theme = SacredTheme.themeFor(AppPalette.highContrast, brightness);
        final text = theme.colorScheme.onSurface.computeLuminance();
        final surface = theme.colorScheme.surface.computeLuminance();
        final ratio = text > surface
            ? (text + .05) / (surface + .05)
            : (surface + .05) / (text + .05);
        expect(ratio, greaterThan(20));
      }
    });
  });

  group('status hafalan', () {
    test(
      'tersimpan, terbaca, dan "belum mulai" tidak menyisakan data',
      () async {
        expect(
          SharedPreferencesService.getMemorizationStatus(78),
          MemorizationStatus.notStarted,
        );
        expect(SharedPreferencesService.memorizationTracked(), isEmpty);

        await SharedPreferencesService.setMemorizationStatus(
          78,
          MemorizationStatus.learning,
        );
        await SharedPreferencesService.setMemorizationStatus(
          114,
          MemorizationStatus.memorized,
        );
        expect(SharedPreferencesService.memorizationTracked(), [78, 114]);

        await SharedPreferencesService.setMemorizationStatus(
          78,
          MemorizationStatus.notStarted,
        );
        expect(SharedPreferencesService.memorizationTracked(), [114]);
      },
    );

    test('urutan status berputar kembali ke awal', () {
      expect(MemorizationStatus.notStarted.next, MemorizationStatus.learning);
      expect(
        MemorizationStatus.needsReview.next,
        MemorizationStatus.notStarted,
      );
    });
  });

  testWidgets(
    'tab Belajar memuat Juz Amma dan menandai fitur yang belum tersedia',
    (tester) async {
      await tester.pumpWidget(_host(const LearnScreen()));
      await tester.pumpAndSettle();

      expect(find.text('An-Naba’'), findsOneWidget);

      await _scrollTo(tester, find.text('An-Nas'));
      expect(find.text('An-Nas'), findsOneWidget);

      // Kartu "belum tersedia" berada di bawah daftar Juz Amma.
      await _scrollTo(tester, find.text('Akademi Tajwid'));
      expect(find.text('Belum tersedia'), findsWidgets);
    },
  );

  testWidgets('ketuk chip status menyimpan hafalan surah', (tester) async {
    await tester.pumpWidget(_host(const LearnScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ubah status hafalan').first);
    await tester.pumpAndSettle();

    expect(
      SharedPreferencesService.getMemorizationStatus(78),
      MemorizationStatus.learning,
    );
  });

  testWidgets(
    'tab Hafalan kosong memberi arahan, lalu menampilkan surah yang ditandai',
    (tester) async {
      await tester.pumpWidget(_host(const MemorizationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada surah yang ditandai.'), findsOneWidget);

      await SharedPreferencesService.setMemorizationStatus(
        112,
        MemorizationStatus.memorized,
      );
      // Widget bertipe sama dipasang ulang akan memakai State lama, jadi
      // kosongkan pohon dulu supaya daftar benar-benar dibaca ulang.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(const MemorizationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Al-Ikhlas'), findsOneWidget);
      expect(find.text('Belum ada surah yang ditandai.'), findsNothing);
    },
  );
}
