import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _today = DateTime(2026, 9, 24);

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: MemorizationScreen(now: () => _today),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              tabs: _tabs,
              currentIndex: 3,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _record(int surah, int from, int to, DateTime due) async {
  for (var ayah = from; ayah <= to; ayah++) {
    await SharedPreferencesService.setAyahMemorization(
      surah,
      ayah,
      AyahMemorization(surah: surah, ayah: ayah, interval: 3, dueOn: due),
    );
  }
}

/// Seperti mockup: An-Naba’ 18/40 (1–10 jatuh tempo), An-Nas & Al-Falaq
/// hafal, Al-Ikhlas perlu murajaah (jatuh tempo). Total 14 ayat jatuh tempo.
Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesService.init();
  final later = _today.add(const Duration(days: 5));
  await SharedPreferencesService.setMemorizationStatus(
    78,
    MemorizationStatus.learning,
  );
  await _record(78, 1, 10, _today);
  await _record(78, 11, 18, later);
  await SharedPreferencesService.setMemorizationStatus(
    114,
    MemorizationStatus.memorized,
  );
  await _record(114, 1, 6, later);
  await SharedPreferencesService.setMemorizationStatus(
    113,
    MemorizationStatus.memorized,
  );
  await _record(113, 1, 5, later);
  await SharedPreferencesService.setMemorizationStatus(
    112,
    MemorizationStatus.needsReview,
  );
  await _record(112, 1, 4, _today);
}

void main() {
  setUpAll(() async => SuraNamesRepository.load());

  for (final variant in GoldenVariant.all) {
    testWidgets('10 hafalan · ${variant.suffix}', (tester) async {
      await tester.runAsync(_seed);
      await pumpGolden(tester, const _Shell(), variant: variant);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(find.text('An-Naba’ 19–23'), findsOneWidget);
      expectNotTruncated(tester, [
        'Mulai sesi',
        'Ziyadah',
        'Murajaah',
        'Tasmi’',
        'Menghafal',
        'Hafal',
        'Perlu murajaah',
        '14 ayat',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/10_hafalan_${variant.suffix}.png'),
      );

      if (variant.textScale != 1) {
        // Daftar surah di teks besar.
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNotTruncated(tester, ['Menghafal', 'Hafal', 'Perlu murajaah']);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/10_hafalan_${variant.suffix}_bawah.png'),
        );
      }
    });
  }
}
