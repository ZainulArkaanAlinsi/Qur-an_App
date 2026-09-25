import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';

/// Tab bar kaca v4: lensa yang meluncur (LIQUID_GLASS.md §6).
const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

Future<List<int>> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  int initial = 0,
}) async {
  final selected = <int>[];
  var index = initial;
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: StatefulBuilder(
            builder: (context, setState) => FloatingTabBar(
              tabs: _tabs,
              currentIndex: index,
              onSelected: (value) {
                selected.add(value);
                setState(() => index = value);
              },
            ),
          ),
        ),
      ),
    ),
  );
  return selected;
}

/// Kapsul lensa: satu-satunya DecoratedBox berwarna primarySoft.
Finder _lens() => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).color ==
          SacredTokens.light.primarySoft,
);

void main() {
  testWidgets('ketuk tab: lensa meluncur, meregang, lalu diam di tab itu', (
    tester,
  ) async {
    final selected = await _pump(tester);
    final start = tester.getRect(_lens());

    await tester.tap(find.text('Hafalan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final moving = tester.getRect(_lens());
    expect(moving.width, greaterThan(start.width), reason: 'lensa meregang');
    expect(moving.width, lessThanOrEqualTo(start.width * 1.12 + .5));
    expect(moving.height, lessThan(start.height));

    await tester.pumpAndSettle();
    expect(selected, [3]);
    final end = tester.getRect(_lens());
    expect(end.width, closeTo(start.width, .01));
    expect(end.height, closeTo(start.height, .01));
    expect(
      end.center.dx,
      closeTo(tester.getCenter(find.text('Hafalan')).dx, 1),
    );
  });

  testWidgets('geser jari di tab bar: lensa mengikuti lalu menempel', (
    tester,
  ) async {
    final selected = await _pump(tester);
    final from = tester.getCenter(find.text('Beranda'));
    final to = tester.getCenter(find.text('Belajar'));

    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(to + const Offset(12, 0));
    await tester.pump();
    // Lensa berada di bawah jari sebelum dilepas.
    expect(tester.getRect(_lens()).center.dx, closeTo(to.dx + 12, 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, [2]);
    expect(tester.getRect(_lens()).center.dx, closeTo(to.dx, 1));
  });

  testWidgets('tanpa ripple Material di tab bar', (tester) async {
    await _pump(tester);
    final bar = find.byType(FloatingTabBar);
    expect(
      find.descendant(of: bar, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byType(InkResponse)),
      findsNothing,
    );
  });

  testWidgets('Kurangi gerak: lensa memudar, tidak meregang', (tester) async {
    final selected = await _pump(tester, reduceMotion: true);
    final start = tester.getRect(_lens());
    await tester.tap(find.text('Saya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Dua lensa sementara (lama memudar, baru muncul), ukurannya tetap.
    expect(_lens(), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(tester.getRect(_lens().at(i)).size, start.size);
    }
    await tester.pumpAndSettle();
    expect(selected, [4]);
    expect(_lens(), findsOneWidget);
    expect(
      tester.getRect(_lens()).center.dx,
      closeTo(tester.getCenter(find.text('Saya')).dx, 1),
    );
  });

  testWidgets('Semantics tetap per tab dan bisa diaktifkan', (tester) async {
    final handle = tester.ensureSemantics();
    final selected = await _pump(tester, initial: 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Qur’an')),
      containsSemantics(
        label: 'Qur’an',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    final learn = find.bySemanticsLabel('Belajar');
    expect(
      tester.getSemantics(learn),
      containsSemantics(isButton: true, isSelected: false),
    );
    tester.semantics.tap(find.semantics.byLabel('Belajar'));
    await tester.pumpAndSettle();
    expect(selected, [2]);
    handle.dispose();
  });
}
