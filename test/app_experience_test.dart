import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
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

/// Memasang tab Belajar dan menunggu kurikulum terbaca (aset dibaca di luar
/// waktu semu).
Future<void> _pumpLearn(WidgetTester tester) async {
  await tester.pumpWidget(_host(const LearnScreen(includeDrafts: false)));
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// Tab Hafalan dengan nama Arab surah yang sudah terbaca.
Future<void> _pumpHafalan(WidgetTester tester) async {
  await tester.pumpWidget(_host(const MemorizationScreen()));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Widget _host(Widget child) => MaterialApp(
  theme: SacredTheme.light,
  home: Scaffold(body: child),
);

void main() {
  // rootBundle menyimpan future aset; muat kurikulum sekali di waktu nyata
  // supaya setiap tes menerimanya.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await CurriculumRepository.load();
  });

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
    'tab Belajar: satu jalur, tanpa layar Akademi Tajwid atau Juz Amma',
    (tester) async {
      await _pumpLearn(tester);

      expect(find.text('Dasar'), findsOneWidget);
      expect(find.text('Tajwid'), findsOneWidget);
      expect(find.text('Mahir'), findsOneWidget);
      // Tahap pertama yang belum selesai menjadi kartu aktif.
      expect(find.text('Mulai dari mana'), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);
      // Layar terpisah yang dulu kosong sudah tidak ada.
      expect(find.text('Akademi Tajwid'), findsNothing);
      // Juz Amma ada di tab Hafalan, bukan di sini.
      await _scrollTo(tester, find.text('An-Naba’'));
      expect(find.text('An-Naba’'), findsNothing);
    },
  );

  testWidgets('tahap draf terkunci di rilis dan menjelaskan alasannya', (
    tester,
  ) async {
    await _pumpLearn(tester);

    await tester.tap(find.text('Mahir'));
    await tester.pumpAndSettle();
    // Tiga tahap terkunci + judul kartu "Materi sedang ditinjau" (v3) yang
    // menawarkan tahap terbit berikutnya.
    expect(find.text('Materi sedang ditinjau'), findsNWidgets(4));
    expect(find.text('Lanjutkan'), findsOneWidget);

    await tester.tap(find.text('Makharij dan sifat'));
    await tester.pump();
    expect(
      find.text('Tahap 14 masih ditinjau guru sebelum bisa dibuka.'),
      findsOneWidget,
    );
  });

  testWidgets('tahap selesai ditandai dan tahap berikutnya jadi aktif', (
    tester,
  ) async {
    await SharedPreferencesService.setLessonCompleted('mulai', true);
    await _pumpLearn(tester);

    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Huruf hijaiyah'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);
  });

  testWidgets('pill status membuka pilihan dan menyimpan status surah', (
    tester,
  ) async {
    await SharedPreferencesService.setMemorizationStatus(
      78,
      MemorizationStatus.learning,
    );
    await _pumpHafalan(tester);

    await tester.tap(find.byTooltip('Ubah status hafalan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hafal').last);
    await tester.pumpAndSettle();
    expect(
      SharedPreferencesService.getMemorizationStatus(78),
      MemorizationStatus.memorized,
    );

    // Menghapus dari daftar tidak lagi terjadi diam-diam lewat putaran
    // status; harus dipilih jelas.
    await tester.tap(find.byTooltip('Ubah status hafalan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus dari daftar'));
    await tester.pumpAndSettle();
    expect(
      SharedPreferencesService.getMemorizationStatus(78),
      MemorizationStatus.notStarted,
    );
  });

  testWidgets('tab Hafalan kosong mengajak memilih surah, tanpa FAB Material', (
    tester,
  ) async {
    await _pumpHafalan(tester);
    expect(find.text('Pilih surah pertama'), findsOneWidget);
    expect(find.text('Tambah surah'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Tambah surah').last);
    await tester.pumpAndSettle();
    // Seperti orang mencari surah: ketik namanya di kolom cari.
    await tester.enterText(find.byType(TextField), 'ikhlas');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Al-Ikhlas'));
    await tester.pumpAndSettle();

    expect(
      SharedPreferencesService.getMemorizationStatus(112),
      MemorizationStatus.learning,
    );
    // Ziyadah hari ini langsung terisi dari surah yang baru ditambah.
    expect(find.text('Al-Ikhlas 1–4'), findsOneWidget);
  });

  testWidgets('nama surah panjang tetap satu baris di samping pill', (
    tester,
  ) async {
    await SharedPreferencesService.setMemorizationStatus(
      2,
      MemorizationStatus.needsReview,
    );
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHafalan(tester);

    final name = tester.renderObject<RenderBox>(find.text('Al-Baqarah'));
    // Satu baris: tingginya satu baris teks, bukan huruf per huruf.
    expect(name.size.height, lessThan(30));
    expect(tester.takeException(), isNull);
  });
}
