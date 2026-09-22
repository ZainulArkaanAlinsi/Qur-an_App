import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';

/// Ukuran logis tetap satu halaman. Halaman tidak pernah di-reflow: kanvas ini
/// di-`contain` ke layar dan diperbesar dengan zoom, jadi baris, pemenggalan,
/// dan urutan kata selalu mengikuti data edisi.
const mushafCanvasSize = Size(360, 560);
const _padding = 12.0;
const _innerWidth = 360 - 2 * _padding;

/// Baris QCF penuh ±15,4–17,3 em (diukur dari metrik font, 22 September 2026).
const mushafFontSize = _innerWidth / 17.6;

/// Baris dengan lebar alami di bawah ambang ini diletakkan di tengah, bukan
/// direntangkan. Heuristik prototipe: data kata tidak membawa penanda
/// "baris tengah".
const _justifyThreshold = .8;

class MushafPageCanvas extends StatelessWidget {
  const MushafPageCanvas({
    super.key,
    required this.page,
    required this.fontFamily,
    required this.surahNames,
    this.basmalah,
    this.selectedVerse,
    this.onVerseTap,
    this.colorFont = false,
  });

  final MushafPage page;

  /// Font halaman QCF untuk [page] (satu edisi).
  final String fontFamily;
  final Map<int, String> surahNames;

  /// Glyph basmalah beserta font halamannya (dari 1:1 di halaman 1 edisi yang
  /// sama), atau `null` bila belum dimuat.
  final ({String fontFamily, List<String> glyphs})? basmalah;
  final String? selectedVerse;
  final ValueChanged<String>? onVerseTap;

  /// Font warna (QCF V4 COLRv1) membawa hitam bawaan untuk huruf non-tajwid
  /// dan tidak memakai warna teks, sehingga tak terbaca di latar gelap.
  /// Halaman seperti ini selalu memakai kertas terang.
  final bool colorFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark && !colorFont;
    final ink = dark ? const Color(0xFFE9E4D6) : SacredTheme.ink;
    final lineHeight = (mushafCanvasSize.height - 2 * _padding) / 15;
    final keys = page.verseKeys;

    return Semantics(
      label:
          'Halaman ${page.number}'
          '${keys.isEmpty ? '' : ', ayat ${keys.first} sampai ${keys.last}'}',
      child: SizedBox.fromSize(
        size: mushafCanvasSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF14201B) : const Color(0xFFFFFDF6),
            border: Border.all(
              color: SacredTheme.gold.withValues(alpha: dark ? .35 : .7),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: page.isOpeningPage
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  for (final line in page.lines)
                    SizedBox(
                      height: lineHeight,
                      width: _innerWidth,
                      child: switch (line) {
                        MushafTextLine(:final words) => _TextLine(
                          words: words,
                          fontFamily: fontFamily,
                          color: ink,
                          centered: page.isOpeningPage,
                          selectedVerse: selectedVerse,
                          onVerseTap: onVerseTap,
                        ),
                        MushafSurahHeader(:final surah) => _SurahHeader(
                          name: surahNames[surah] ?? '$surah',
                          color: ink,
                        ),
                        MushafBasmalah() => _Basmalah(
                          basmalah: basmalah,
                          color: ink,
                        ),
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLine extends StatelessWidget {
  const _TextLine({
    required this.words,
    required this.fontFamily,
    required this.color,
    required this.centered,
    required this.selectedVerse,
    required this.onVerseTap,
  });

  final List<MushafWord> words;
  final String fontFamily;
  final Color color;
  final bool centered;
  final String? selectedVerse;
  final ValueChanged<String>? onVerseTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: mushafFontSize,
      height: 1.0,
      color: color,
    );
    var natural = 0.0;
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(text: word.glyph, style: style),
        textDirection: TextDirection.rtl,
      )..layout();
      natural += painter.width;
      painter.dispose();
    }
    final highlight = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: .16);
    final children = [
      for (final word in words)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onVerseTap == null ? null : () => onVerseTap!(word.verseKey),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: word.verseKey == selectedVerse ? highlight : null,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(word.glyph, style: style, softWrap: false),
          ),
        ),
    ];

    final justify = !centered && natural >= _innerWidth * _justifyThreshold;
    final gap = mushafFontSize * .12;
    final row = Row(
      mainAxisSize: justify ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: justify
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.center,
      children: justify
          ? children
          : [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                children[i],
              ],
            ],
    );
    final minimumWidth = natural + (justify ? 0 : gap * (words.length - 1));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        // Baris yang sedikit lebih lebar dari kanvas diperkecil, bukan
        // dipindah ke baris lain.
        child: minimumWidth > _innerWidth
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: minimumWidth, child: row),
              )
            : SizedBox(width: justify ? _innerWidth : null, child: row),
      ),
    );
  }
}

/// Bingkai judul orisinal (bukan salinan ornamen mushaf cetak).
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gold = SacredTheme.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: gold, width: 1.4),
          borderRadius: BorderRadius.circular(18),
          color: gold.withValues(alpha: .10),
        ),
        child: Center(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'سُورَةُ $name',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: mushafFontSize * .95,
                height: 1.0,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Basmalah extends StatelessWidget {
  const _Basmalah({required this.basmalah, required this.color});

  final ({String fontFamily, List<String> glyphs})? basmalah;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final data = basmalah;
    if (data == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            data.glyphs.join(' '),
            style: TextStyle(
              fontFamily: data.fontFamily,
              fontSize: mushafFontSize,
              height: 1.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skala agar kanvas muat penuh di [available] tanpa distorsi.
double mushafFitScale(Size available) => math.min(
  available.width / mushafCanvasSize.width,
  available.height / mushafCanvasSize.height,
);
