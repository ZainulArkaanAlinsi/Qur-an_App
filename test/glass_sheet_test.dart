import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';

/// Sheet kaca v4: kepala berkaca (grabber + judul), isi padat
/// (LIQUID_GLASS.md §2, §6).
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SacredTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showGlassSheet<void>(
                  context: context,
                  header: (_) => const Text('Judul sheet'),
                  builder: (_) => const SizedBox(
                    height: 300,
                    child: Center(child: Text('Isi sheet')),
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('judul di kepala kaca, isi di permukaan padat surf', (
    tester,
  ) async {
    await open(tester);
    final glass = find.byType(LiquidGlass);
    expect(glass, findsOneWidget);
    expect(tester.widget<LiquidGlass>(glass).size, GlassSize.sheet);
    expect(
      find.descendant(of: glass, matching: find.text('Judul sheet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: glass, matching: find.text('Isi sheet')),
      findsNothing,
    );
    final body = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.text('Isi sheet'),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(
      body.color,
      SacredTheme.tokensFor(AppPalette.sacred, Brightness.light).surf,
    );
  });

  testWidgets('grabber meregang saat sheet ditarik turun', (tester) async {
    await open(tester);
    Finder grabber() => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxHeight == 5 &&
          widget.decoration is BoxDecoration,
    );
    final rest = tester.getSize(grabber()).width;
    expect(rest, 36);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Judul sheet')),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    final pulled = tester.getSize(grabber()).width;
    expect(pulled, greaterThan(rest));
    expect(pulled, lessThanOrEqualTo(rest * 1.3 + .01));

    // Dilepas tanpa lemparan: sheet kembali terbuka, grabber normal.
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(grabber()).width, rest);
  });
}
