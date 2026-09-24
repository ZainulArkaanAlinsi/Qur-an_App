import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
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

class _Shell extends StatelessWidget {
  const _Shell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return AppScope(
      controller: controller,
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: Stack(
          children: [
            const Positioned.fill(
              child: SafeArea(bottom: false, child: SettingsScreen()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingTabBar(
                tabs: _tabs,
                currentIndex: 4,
                onSelected: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async => JuzRepository.load());

  for (final variant in GoldenVariant.all) {
    testWidgets('12 saya · ${variant.suffix}', (tester) async {
      late AppController controller;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferencesService.init();
        // Istiqamah 2 hari dan beberapa menit minggu ini.
        final now = DateTime.now();
        for (var i = 1; i <= 2; i++) {
          await SharedPreferencesService.setReadingSeconds(
            ReadingProgressService.localDate(
              DateTime(now.year, now.month, now.day - i),
            ),
            600,
          );
        }
        controller = AppController();
      });
      await pumpGolden(
        tester,
        _Shell(controller: controller),
        variant: variant,
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      // Judul besar hanya sekali (bug lama: dobel) + label tab.
      expect(find.text('Saya'), findsNWidgets(2));
      expect(find.text('Belum masuk'), findsOneWidget);
      expectNotTruncated(tester, [
        'Progres lengkap',
        'hari istiqamah',
        'menit minggu ini',
        'juz khatam',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/12_saya_${variant.suffix}.png'),
      );
    });
  }
}
