import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

/// Tab Belajar dalam kerangka AppShell, tampilan rilis (tanpa draf).
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: LearnScreen(includeDrafts: false),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              tabs: _tabs,
              currentIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Seperti mockup: "Mulai dari mana" selesai, Huruf hijaiyah di bagian 2.
Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService.init();
  await SharedPreferencesService.setLessonCompleted('mulai', true);
  await SharedPreferencesService.setLessonStep('huruf-hijaiyah', 2);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(() async => CurriculumRepository.load());

  for (final variant in GoldenVariant.all) {
    testWidgets('08 belajar · ${variant.suffix}', (tester) async {
      await tester.runAsync(_seed);
      await pumpGolden(tester, const _Shell(), variant: variant);
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Huruf hijaiyah'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expectNotTruncated(tester, [
        'Dasar',
        'Tajwid',
        'Mahir',
        'Lanjutkan',
        'Huruf hijaiyah',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/08_belajar_${variant.suffix}.png'),
      );
    });
  }

  // Pengganti layar "Akademi Tajwid" yang kosong: tahap 10–13 terlihat,
  // terkunci, dan diberi keterangan.
  testWidgets('08 belajar · segmen Tajwid saat materi masih ditinjau', (
    tester,
  ) async {
    await tester.runAsync(_seed);
    await pumpGolden(tester, const _Shell());
    await _settle(tester);

    await tester.tap(find.text('Tajwid'));
    await tester.pumpAndSettle();

    expect(find.text('Nun sukun dan tanwin'), findsOneWidget);
    expect(find.text('Materi sedang ditinjau'), findsWidgets);
    expect(
      find.textContaining('sedang ditinjau guru bersanad'),
      findsOneWidget,
    );

    // Tahap terkunci tidak membuka layar kosong; ia menjelaskan alasannya.
    await tester.tap(find.text('Nun sukun dan tanwin'));
    await tester.pump();
    expect(
      find.text('Tahap 10 masih ditinjau guru sebelum bisa dibuka.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08_belajar_tajwid_light.png'),
    );
  });
}
