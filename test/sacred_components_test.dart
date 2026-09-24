import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Size size = const Size(390, 844),
  AppPalette palette = AppPalette.sacred,
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.themeFor(palette, brightness),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('lengkung mihrab', () {
    test('mengikuti rumus spesifikasi dan tertutup di dalam kotak', () {
      const size = Size(200, 300);
      final path = MihrabClipper.pathFor(size);
      final bounds = path.getBounds();

      expect(bounds.left, greaterThanOrEqualTo(-0.01));
      expect(bounds.top, greaterThanOrEqualTo(-0.01));
      expect(bounds.right, lessThanOrEqualTo(size.width + 0.01));
      expect(bounds.bottom, lessThanOrEqualTo(size.height + 0.01));

      // Puncak lengkung berada di tengah atas, dan sudut atas kosong.
      expect(path.contains(const Offset(100, 1)), isTrue);
      expect(path.contains(const Offset(2, 2)), isFalse);
      // Bagian bawah tetap persegi dengan sudut membulat.
      expect(path.contains(const Offset(100, 290)), isTrue);
    });

    test('radius tidak pernah melebihi setengah sisi terpendek', () {
      final path = MihrabClipper.pathFor(const Size(20, 20), radius: 999);
      expect(path.getBounds().width, lessThanOrEqualTo(20.01));
    });
  });

  test('penanda ayat memakai angka Arab-Indik', () {
    expect(RosetteBadge.arabicNumerals(1), '١');
    expect(RosetteBadge.arabicNumerals(255), '٢٥٥');
    expect(RosetteBadge.arabicNumerals(604), '٦٠٤');
  });

  testWidgets('penanda ayat membawa label yang terbaca pembaca layar', (
    tester,
  ) async {
    await _pump(tester, Center(child: RosetteBadge.ayah(7)));
    expect(find.bySemanticsLabel('Ayat 7'), findsOneWidget);
  });

  testWidgets('penanda ayat memakai font Al-Quran, bukan font Latin', (
    tester,
  ) async {
    // Font Latin yang dibundel sudah dipangkas dan tidak punya angka
    // Arab-Indik; memakainya membuat penanda ayat tampil kosong.
    await _pump(tester, Center(child: RosetteBadge.ayah(255)));
    final text = tester.widget<Text>(find.text('٢٥٥'));
    expect(text.style!.fontFamily, SacredText.quran);
  });

  testWidgets('segmented control memilih segmen dan menandainya', (
    tester,
  ) async {
    var value = 'surah';
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SegmentedPill<String>(
          segments: const {
            'surah': 'Surah',
            'juz': 'Juz',
            'halaman': 'Halaman',
          },
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
      ),
    );

    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();
    expect(value, 'juz');
  });

  testWidgets('toggle iOS berpindah dan punya target sentuh >= 44 px', (
    tester,
  ) async {
    var value = false;
    await _pump(
      tester,
      Center(
        child: StatefulBuilder(
          builder: (context, setState) => IosToggle(
            value: value,
            semanticsLabel: 'Hemat kuota',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(IosToggle));
    expect(box.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byType(IosToggle));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  group('tab bar mengambang', () {
    testWidgets('lima tab tanpa tombol cari terpisah', (tester) async {
      var selected = 0;
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: StatefulBuilder(
            builder: (context, setState) => FloatingTabBar(
              tabs: _tabs,
              currentIndex: selected,
              onSelected: (index) => setState(() => selected = index),
            ),
          ),
        ),
      );

      for (final label in ['Beranda', 'Qur’an', 'Belajar', 'Hafalan', 'Saya']) {
        expect(find.text(label), findsOneWidget);
      }
      // Cari pindah ke header Beranda & Qur'an (CLAUDE.md).
      expect(find.byTooltip('Cari'), findsNothing);

      await tester.tap(find.text('Hafalan'));
      await tester.pumpAndSettle();
      expect(selected, 3);
    });

    testWidgets('tidak meluber pada text scale 200% dan layar 320 dp', (
      tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FloatingTabBar(
            tabs: _tabs,
            currentIndex: 1,
            onSelected: (_) {},
          ),
        ),
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('komponen dasar tidak meluber pada text scale 200%', (
    tester,
  ) async {
    await _pump(
      tester,
      ListView(
        children: [
          const LargeTitle('Qur’an', subtitle: '114 surah · 30 juz'),
          SegmentedPill<int>(
            segments: const {0: 'Surah', 1: 'Juz', 2: 'Halaman'},
            value: 0,
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          InsetGroupedList(
            header: 'Tampilan',
            children: [
              ListTile(
                title: const Text('Tema aplikasi'),
                trailing: IosToggle(value: true, onChanged: (_) {}),
              ),
              const ListTile(title: Text('Ukuran huruf Arab')),
            ],
          ),
          const SizedBox(height: 12),
          SkyStrip(
            period: SkyPeriod.dusk,
            child: Row(
              children: [
                const Icon(Icons.wb_twilight_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ashar 14:57',
                    style: SacredText.headline.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: MihrabFrame(
              child: Stack(
                children: [
                  const Positioned.fill(child: GeometricPattern()),
                  Center(child: RosetteBadge.ayah(18)),
                ],
              ),
            ),
          ),
        ],
      ),
      textScale: 2,
      size: const Size(320, 900),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('komponen tetap terbaca di gelap dan sepia', (tester) async {
    for (final (palette, brightness) in [
      (AppPalette.sacred, Brightness.dark),
      (AppPalette.sepia, Brightness.light),
      (AppPalette.highContrast, Brightness.dark),
    ]) {
      await _pump(
        tester,
        Column(
          children: [
            const LargeTitle('Beranda'),
            SegmentedPill<int>(
              segments: const {0: 'Surah', 1: 'Juz'},
              value: 1,
              onChanged: (_) {},
            ),
            IosToggle(value: true, onChanged: (_) {}),
          ],
        ),
        palette: palette,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull, reason: '$palette $brightness');
    }
  });
}
