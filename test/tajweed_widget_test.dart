import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_verse_panel.dart';

final _fixture = jsonDecode(
  File('test/fixtures/qf_uthmani_tajweed_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

String _markup(String key) => (_fixture['verses'] as List)
    .cast<Map<String, dynamic>>()
    .firstWhere((v) => v['verse_key'] == key)['text_uthmani_tajweed'] as String;

String get _malformed32v3 => ((_fixture['malformed_verses'] as List).single
    as Map<String, dynamic>)['text_uthmani_tajweed'] as String;

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? SacredTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

const _style = TextStyle(fontSize: 28);

/// Span ayat Arab: RichText yang teks polosnya sama dengan [text].
TextSpan _verseSpan(WidgetTester tester, String text) {
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((w) => w.text.toPlainText() == text);
  return richText.text as TextSpan;
}

/// `Text.rich` membungkus span kita dengan DefaultTextStyle, jadi telusuri
/// seluruh pohon span.
List<TextSpan> _coloredSpans(TextSpan root) {
  final spans = <TextSpan>[];
  root.visitChildren((span) {
    if (span is TextSpan && span.recognizer != null) spans.add(span);
    return true;
  });
  return spans;
}

void main() {
  const parser = TajweedMarkupParser();

  testWidgets('teks ayat identik dengan data dan segmen diwarnai palet',
      (tester) async {
    final verse = parser.parse('1:1', _markup('1:1'));
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '1:1',
      markup: _markup('1:1'),
      fallbackText: '-',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
    )));

    final root = _verseSpan(tester, verse.text);
    final colored = _coloredSpans(root);
    expect(colored, hasLength(verse.runs.where((r) => r.rule != null).length));
    for (final span in colored) {
      expect(
        TajweedPalette.draftPreview.light.values,
        contains(span.style!.color),
      );
    }
  });

  testWidgets('chip menampilkan nama hukum dan jumlah kemunculan',
      (tester) async {
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '1:1',
      markup: _markup('1:1'),
      fallbackText: '-',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
    )));

    expect(find.text('Hamzah Washal ×3'), findsOneWidget);
    expect(find.text('Lam Syamsiyah ×2'), findsOneWidget);
    expect(find.text("Mad Thabi'i ×1"), findsOneWidget);
    expect(find.text('Mad Jaiz ×1'), findsOneWidget);

    await tester.tap(find.text('Hamzah Washal ×3'));
    await tester.pumpAndSettle();
    expect(find.text('Muncul 3 kali pada ayat ini.'), findsOneWidget);
    expect(find.textContaining('DRAF'), findsOneWidget);
    expect(find.text('Akademi Tajwid belum tersedia'), findsOneWidget);
  });

  testWidgets('ketuk segmen menyorot rentangnya dan membuka nama hukum',
      (tester) async {
    final verse = parser.parse('2:190', _markup('2:190'));
    TajweedRule? learned;
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '2:190',
      markup: _markup('2:190'),
      fallbackText: '-',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
      onLearnRule: (rule) => learned = rule,
    )));

    // Segmen `slnt` bersarang di dalam `madda_obligatory`: yang terdalam menang.
    final silentColor =
        TajweedPalette.draftPreview.light[TajweedRule.silent]!;
    final silentSpan = _coloredSpans(_verseSpan(tester, verse.text))
        .firstWhere((s) => s.style!.color == silentColor);
    (silentSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Huruf tidak dibaca'), findsOneWidget);
    final highlighted = _coloredSpans(_verseSpan(tester, verse.text))
        .where((s) => s.style!.backgroundColor != null);
    expect(highlighted, isNotEmpty);
    expect(highlighted.every((s) => s.style!.color == silentColor), isTrue);

    await tester.tap(find.text('Pelajari hukum ini'));
    await tester.pumpAndSettle();
    expect(learned, TajweedRule.silent);
    expect(
      _coloredSpans(_verseSpan(tester, verse.text))
          .where((s) => s.style!.backgroundColor != null),
      isEmpty,
    );
  });

  testWidgets('markup rusak: teks cadangan tanpa warna dan error dilaporkan',
      (tester) async {
    String? reported;
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '32:3',
      markup: _malformed32v3,
      fallbackText: 'teks polos edisi cadangan',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
      onParseError: (key, _) => reported = key,
    )));
    await tester.pump();

    expect(find.text('teks polos edisi cadangan'), findsOneWidget);
    expect(
      find.text(
        'Warna tajwid tidak tersedia untuk ayat ini. Ditampilkan: edisi uji.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ActionChip), findsNothing);
    expect(reported, '32:3');
  });

  testWidgets('tajwid dimatikan: teks sama tanpa warna dan tanpa chip',
      (tester) async {
    final verse = parser.parse('1:1', _markup('1:1'));
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '1:1',
      markup: _markup('1:1'),
      fallbackText: '-',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
      tajweedEnabled: false,
    )));

    expect(find.text(verse.text), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('legend bisa dibuka dari kartu', (tester) async {
    await tester.pumpWidget(_host(TajweedVersePanel(
      verseKey: '1:1',
      markup: _markup('1:1'),
      fallbackText: '-',
      fallbackEditionLabel: 'edisi uji',
      arabicStyle: _style,
    )));
    await tester.tap(find.byTooltip('Legend warna tajwid'));
    await tester.pumpAndSettle();
    expect(find.text('Legend tajwid · Pratinjau'), findsOneWidget);
    expect(find.text(TajweedRule.values.first.nameId), findsOneWidget);
  });

  test('setiap warna palet berkontras >= 4:1 terhadap permukaan kartu', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
    }

    for (final (brightness, theme) in [
      (Brightness.light, SacredTheme.light),
      (Brightness.dark, SacredTheme.dark),
    ]) {
      final surfaces = [
        theme.colorScheme.surface,
        theme.colorScheme.surfaceContainerLowest,
        theme.cardTheme.color!,
      ];
      for (final rule in TajweedRule.values) {
        final color = TajweedPalette.draftPreview.colorFor(rule, brightness);
        for (final surface in surfaces) {
          expect(
            contrast(color, surface),
            greaterThanOrEqualTo(4.0),
            reason: '$brightness ${rule.name} vs $surface',
          );
        }
      }
    }
  });
}
