import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

/// Ayat sesi: teks Tanzil apa adanya (awalan basmalah dibuang), satu paragraf
/// RTL, dengan kata yang disorot di belakang huruf. Sorotan dan ketukan hanya
/// per kata; bentuk huruf Arab tidak pernah dipecah.
///
/// - [onWordTap] diisi: mengetuk kata memanggilnya dengan nomor kata
///   (1-based, penomoran `tanzilWords()`), dan pembaca layar mendapat aksi
///   "Pilih kata N" per kata.
/// - [onRuleTap] diisi dan [tajweed] ada: mengetuk huruf berwarna membuka
///   hukumnya.
class SessionVerseView extends StatelessWidget {
  const SessionVerseView({
    super.key,
    required this.verse,
    required this.semanticsLabel,
    this.highlighted = const {},
    this.wrong = const {},
    this.tajweed,
    this.onWordTap,
    this.onRuleTap,
    this.fontSize = 30,
  });

  final VerseWords verse;
  final String semanticsLabel;

  /// Kata yang disorot (latar goldSoft, garis bawah goldText).
  final Set<int> highlighted;

  /// Kata yang diketuk tapi bukan jawabannya (latar dangerSoft).
  final Set<int> wrong;

  final TajweedVerse? tajweed;
  final ValueChanged<int>? onWordTap;
  final ValueChanged<TajweedRule>? onRuleTap;
  final double fontSize;

  int get _start => verse.words.isEmpty ? 0 : verse.words.first.start;

  TextSpan _span(SacredTokens tokens) {
    final style = TextStyle(
      fontFamily: SacredText.quran,
      fontSize: fontSize,
      height: 2.0,
      color: tokens.ink,
    );
    final colored = tajweed;
    return TextSpan(
      style: style,
      children: colored == null
          ? [TextSpan(text: verse.text.substring(_start))]
          : tajweedSpans(
              colored,
              palette: TajweedPalette.draftPreview,
              brightness: tokens.isDark ? Brightness.dark : Brightness.light,
              base: tokens.ink,
              from: _start,
            ),
    );
  }

  /// Nomor kata pada offset teks ayat, atau null di antara kata.
  int? _wordAt(int offset) {
    for (var index = 0; index < verse.words.length; index++) {
      final word = verse.words[index];
      if (offset >= word.start && offset < word.end) return index + 1;
    }
    return null;
  }

  TajweedRule? _ruleAt(int offset) {
    for (final run in tajweed?.runs ?? const <TajweedRun>[]) {
      if (run.rule != null && offset >= run.start && offset < run.end) {
        return run.rule;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter =
            TextPainter(
              text: _span(tokens),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              textScaler: scaler,
            )..layout(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
            );

        List<TextBox> boxesOf(int position) {
          final word = verse.words[position - 1];
          return painter.getBoxesForSelection(
            TextSelection(
              baseOffset: word.start - _start,
              extentOffset: word.end - _start,
            ),
          );
        }

        final marks = [
          for (final position in highlighted)
            if (position >= 1 && position <= verse.words.length)
              (boxesOf(position), tokens.goldSoft, tokens.goldText),
          for (final position in wrong)
            if (position >= 1 && position <= verse.words.length)
              (boxesOf(position), tokens.dangerSoft, tokens.danger),
        ];

        final tapWord = onWordTap;
        final tapRule = tajweed == null ? null : onRuleTap;
        return Semantics(
          label: semanticsLabel,
          textDirection: TextDirection.rtl,
          customSemanticsActions: tapWord == null
              ? null
              : {
                  for (var index = 1; index <= verse.words.length; index++)
                    CustomSemanticsAction(label: 'Pilih kata $index'): () =>
                        tapWord(index),
                },
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: tapWord == null && tapRule == null
                  ? null
                  : (details) {
                      final offset =
                          painter
                              .getPositionForOffset(details.localPosition)
                              .offset +
                          _start;
                      if (tapWord != null) {
                        final word = _wordAt(offset);
                        if (word != null) tapWord(word);
                        return;
                      }
                      final rule = _ruleAt(offset);
                      if (rule != null) tapRule!(rule);
                    },
              child: CustomPaint(
                size: Size(constraints.maxWidth, painter.height),
                painter: _VersePainter(painter, marks),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VersePainter extends CustomPainter {
  _VersePainter(this.text, this.marks);

  final TextPainter text;
  final List<(List<TextBox>, Color, Color)> marks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (boxes, fill, line) in marks) {
      for (final box in boxes) {
        final rect = box.toRect();
        // Latar setinggi huruf (bukan setinggi baris 2.0), sedikit melebar.
        final inner = Rect.fromLTRB(
          rect.left - 3,
          rect.top + rect.height * .18,
          rect.right + 3,
          rect.bottom - rect.height * .12,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, const Radius.circular(6)),
          Paint()..color = fill,
        );
        canvas.drawRect(
          Rect.fromLTRB(
            inner.left,
            inner.bottom - 2,
            inner.right,
            inner.bottom,
          ),
          Paint()..color = line,
        );
      }
    }
    text.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_VersePainter old) =>
      old.text != text || old.marks != marks;
}
