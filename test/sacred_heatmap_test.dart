import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/widgets/sacred_heatmap.dart';

HeatCell _cell(int seconds, {int target = 300}) => HeatCell(
  date: DateTime(2026, 9, 23),
  seconds: seconds,
  targetSeconds: target,
);

void main() {
  group('tingkat heatmap dihitung terhadap target hari itu', () {
    test('hari tanpa bacaan berada di tingkat nol', () {
      expect(_cell(0).level, 0);
    });

    test('target tercapai selalu tingkat penuh', () {
      expect(_cell(300).level, 3);
      expect(_cell(900).level, 3);
    });

    test('target yang lebih besar menurunkan tingkat hari yang sama', () {
      expect(_cell(240, target: 300).level, 2);
      expect(_cell(240, target: 1800).level, 1);
    });

    test('target nol tidak membuat pembagian tak hingga', () {
      expect(_cell(60, target: 0).level, 3);
    });
  });

  testWidgets('tiap hari punya label yang terbaca pembaca layar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.themeFor(AppPalette.sacred, Brightness.light),
        home: Scaffold(
          body: SacredHeatmap(
            cells: [
              HeatCell(
                date: DateTime(2026, 9, 22),
                seconds: 0,
                targetSeconds: 300,
              ),
              HeatCell(
                date: DateTime(2026, 9, 23),
                seconds: 420,
                targetSeconds: 300,
                isToday: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('22/9: belum membaca'), findsOneWidget);
    expect(find.bySemanticsLabel('23/9: 7 menit'), findsOneWidget);
  });
}
